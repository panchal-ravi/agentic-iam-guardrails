"""Tests for settings loading from .env and environment variables."""

from unittest.mock import patch

from config.settings import Settings


class TestSettings:
    def test_reads_values_from_dotenv_file(self, tmp_path, monkeypatch):
        dotenv_path = tmp_path / ".env"
        dotenv_path.write_text(
            "IDENTITY_BROKER_VERIFY_BASE_URL=https://tenant.verify.ibm.com\n"
            "IDENTITY_BROKER_OBO_CLIENT_ID=dotenv-client-id\n"
        )
        monkeypatch.chdir(tmp_path)

        settings = Settings()

        assert settings.verify_base_url == "https://tenant.verify.ibm.com"
        assert settings.obo_client_id == "dotenv-client-id"

    def test_environment_variables_override_dotenv_values(self, tmp_path, monkeypatch):
        dotenv_path = tmp_path / ".env"
        dotenv_path.write_text(
            "IDENTITY_BROKER_VERIFY_BASE_URL=https://dotenv.verify.ibm.com\n"
            "IDENTITY_BROKER_OBO_CLIENT_ID=dotenv-client-id\n"
        )
        monkeypatch.chdir(tmp_path)
        monkeypatch.setenv(
            "IDENTITY_BROKER_VERIFY_BASE_URL",
            "https://env.verify.ibm.com",
        )

        settings = Settings()

        assert settings.verify_base_url == "https://env.verify.ibm.com"
        assert settings.obo_client_id == "dotenv-client-id"

    def test_log_configured_values_logs_all_fields(self):
        settings = Settings(
            vault_addr="https://vault.example.com",
            vault_tls_verify=False,
            vault_ca_bundle="/tmp/vault-ca.pem",
            verify_base_url="https://tenant.verify.ibm.com",
            obo_client_id="client-id",
            cache_ttl=120,
            cache_maxsize=50,
            log_level="DEBUG",
        )

        with patch("config.settings.logger") as mock_logger:
            settings.log_configured_values()

        mock_logger.info.assert_called_once_with(
            "settings_loaded",
            vault_addr="https://vault.example.com",
            vault_tls_verify=False,
            vault_ca_bundle="/tmp/vault-ca.pem",
            verify_base_url="https://tenant.verify.ibm.com",
            obo_client_id="client-id",
            cache_ttl=120,
            cache_maxsize=50,
            log_level="DEBUG",
        )
