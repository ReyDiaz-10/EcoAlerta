"""Comprobación manual segura de Supabase.

Uso: python test_supabase_conn.py
"""

from app.db import DatabaseError, healthcheck


if __name__ == "__main__":
    try:
        healthcheck()
        print("Conexión con Supabase correcta.")
    except DatabaseError:
        print("No fue posible conectar con Supabase. Revise URL, clave y migración.")
        raise SystemExit(1)
