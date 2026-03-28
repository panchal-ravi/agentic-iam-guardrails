import time
from dataclasses import dataclass

import tenacity
import tenacity.stop
import tenacity.wait

from broker.cache import TokenCache
from exceptions.errors import VerifyTokenExchangeError
from app_logging.logger import get_logger
from verify.verify_client import IBMVerifyClient

logger = get_logger(__name__)


@dataclass
class OBOTokenResult:
    access_token: str
    cached: bool


class OBOBroker:
    """Broker that performs an IBM Verify on-behalf-of (OBO) token exchange.

    Public API:
        exchange_obo_token(subject_token, actor_token) -> OBOTokenResult
    """

    def __init__(
        self,
        verify_client: IBMVerifyClient | None = None,
        cache: TokenCache | None = None,
    ) -> None:
        self._client = verify_client or IBMVerifyClient()
        self._cache = cache or TokenCache()

    def exchange_obo_token(
        self, subject_token: str, actor_token: str
    ) -> OBOTokenResult:
        """Return an IBM Verify access token on behalf of *subject_token*.

        Checks the cache first using a hashed key derived from both input tokens.
        On a cache miss, calls IBM Verify with automatic retry (3 attempts,
        exponential backoff) on transient failures.

        Args:
            subject_token: The caller's access token (JWT).
            actor_token:   The Vault Identity JWT acting on behalf of the subject.

        Returns:
            :class:`OBOTokenResult` with the access token and cache flag.

        Raises:
            VerifyAuthenticationError:  IBM Verify rejected the request.
            VerifyTokenExchangeError:   IBM Verify could not complete the exchange.
            CacheError:                 Unexpected cache failure.
        """
        start = time.monotonic()

        # Build a synthetic "role" string so we can reuse TokenCache's two-arg API.
        # The actual cache key is sha256(subject_token + actor_token).
        cached_token = self._cache.get(subject_token, actor_token)
        if cached_token:
            duration_ms = int((time.monotonic() - start) * 1000)
            logger.info(
                "verify_obo_token_exchange",
                cache_hit=True,
                duration_ms=duration_ms,
            )
            return OBOTokenResult(access_token=cached_token, cached=True)

        response_data = self._fetch_with_retry(subject_token, actor_token)
        access_token: str = response_data["access_token"]
        self._cache.set(subject_token, actor_token, access_token)

        duration_ms = int((time.monotonic() - start) * 1000)
        logger.info(
            "verify_obo_token_exchange",
            cache_hit=False,
            duration_ms=duration_ms,
        )
        return OBOTokenResult(access_token=access_token, cached=False)

    @tenacity.retry(
        retry=tenacity.retry_if_exception_type(VerifyTokenExchangeError),
        stop=tenacity.stop.stop_after_attempt(3),
        wait=tenacity.wait.wait_exponential(multiplier=0.5, min=0.5, max=4),
        reraise=True,
    )
    def _fetch_with_retry(self, subject_token: str, actor_token: str) -> dict:
        return self._client.exchange_obo_token(subject_token, actor_token)
