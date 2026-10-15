import pyodbc
from dotenv import load_dotenv
load_dotenv()
from app.config import CONEXION_CADENA, SQL_SERVER_NAME, SQL_DATABASE_NAME
print('CONEXION_CADENA=', CONEXION_CADENA)
print('SERVER=', SQL_SERVER_NAME, 'DB=', SQL_DATABASE_NAME)
servers = ['FarithNew', 'localhost\\FarithNew', '.\\FarithNew', '127.0.0.1\\FarithNew']
for s in servers:
    conn_str = f"Driver={{ODBC Driver 17 for SQL Server}};Server={s};Database=BuzonAmbiental;Trusted_Connection=yes;"
    try:
        conn = pyodbc.connect(conn_str, timeout=5)
        cur = conn.cursor()
        cur.execute('SELECT COUNT(*) FROM ReportesAmbientales')
        count = cur.fetchone()[0]
        cur.execute('SELECT TOP 1 radicado, tipo_problema, color, entidad_destino FROM ReportesAmbientales ORDER BY fecha_registro DESC')
        sample = cur.fetchone()
        print('OK', s, 'count=', count, 'sample=', sample)
        cur.close()
        conn.close()
    except Exception as exc:
        print('FAIL', s, exc)
