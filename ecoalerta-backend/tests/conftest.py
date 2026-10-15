import os

os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("JWT_SECRET", "test-secret-with-more-than-thirty-two-characters")
os.environ.setdefault("SUPABASE_URL", "")
os.environ.setdefault("SUPABASE_SERVICE_KEY", "")
os.environ.setdefault("GENAI_API_KEY", "")
os.environ.setdefault("EMAIL_DELIVERY_ENABLED", "false")
os.environ.setdefault("TRUSTED_HOSTS", "testserver,localhost,127.0.0.1")
