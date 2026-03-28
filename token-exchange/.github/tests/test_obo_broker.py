"""Unit tests for OBOBroker."""
import time
from unittest.mock import MagicMock

import jwt
import pytest

from broker.cache import TokenCache
from exceptions.errors import (
    VerifyAuthenticationError,
    VerifyTokenExchangeError,
)
from verify.obo_broker import OBOBroker
from verify.verify_client import IBMVerifyClient


def _make_jwt(exp_offset: int = 3600) -> str:
    payload = {"sub": "user", "exp": int(time.time()) + exp_offset}
    return jwt.encode(payload, "secret", algorithm="HS256")


@pytest.fixture()
def mock_verify_client():
    return MagicMock(spec=IBMVerifyClient)


@pytest.fixture()
def fresh_cache():
    return TokenCache(maxsize=10, ttl=60)


class TestExchangeOBOToken:
    def test_cache_miss_calls_verify_and_caches(self, mock_verify_client, fresh_cache):
        access_token = _make_jwt()
        mock_verify_client.exchange_obo_token.return_value = {"access_token": access_token}

        broker = OBOBroker(verify_client=mock_verify_client, cache=fresh_cache)
        result = broker.exchange_obo_token("subject-tok", "actor-tok")

        assert result.access_token == access_token
        assert result.cached is False
        mock_verify_client.exchange_obo_token.assert_called_once_with("subject-tok", "actor-tok")

    def test_cache_hit_skips_verify(self, mock_verify_client, fresh_cache):
        access_token = _make_jwt()
        # Pre-populate the cache using the same key derivation as OBOBroker
        fresh_cache.set("subject-tok", "actor-tok", access_token)

        broker = OBOBroker(verify_client=mock_verify_client, cache=fresh_cache)
        result = broker.exchange_obo_token("subject-tok", "actor-tok")

        assert result.access_token == access_token
        assert result.cached is True
        mock_verify_client.exchange_obo_token.assert_not_called()

    def test_verify_auth_error_propagates(self, mock_verify_client, fresh_cache):
        mock_verify_client.exchange_obo_token.side_effect = VerifyAuthenticationError("401")

        broker = OBOBroker(verify_client=mock_verify_client, cache=fresh_cache)
        with pytest.raises(VerifyAuthenticationError):
            broker.exchange_obo_token("subject-tok", "actor-tok")

    def test_verify_exchange_error_retries_then_raises(self, mock_verify_client, fresh_cache):
        mock_verify_client.exchange_obo_token.side_effect = VerifyTokenExchangeError("server error")

        broker = OBOBroker(verify_client=mock_verify_client, cache=fresh_cache)
        with pytest.raises(VerifyTokenExchangeError):
            broker.exchange_obo_token("subject-tok", "actor-tok")

        # tenacity retries 3 times
        assert mock_verify_client.exchange_obo_token.call_count == 3

    def test_different_token_pairs_use_separate_cache_entries(self, mock_verify_client, fresh_cache):
        token_a = _make_jwt()
        token_b = _make_jwt()
        mock_verify_client.exchange_obo_token.side_effect = [
            {"access_token": token_a},
            {"access_token": token_b},
        ]

        broker = OBOBroker(verify_client=mock_verify_client, cache=fresh_cache)
        result_a = broker.exchange_obo_token("subject-a", "actor-a")
        result_b = broker.exchange_obo_token("subject-b", "actor-b")

        assert result_a.access_token == token_a
        assert result_b.access_token == token_b
        assert mock_verify_client.exchange_obo_token.call_count == 2
