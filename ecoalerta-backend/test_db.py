import pyodbc

# Tu cadena de conexión ya corregida
conexion_cadena = (
    "Driver={ODBC Driver 17 for SQL Server};"
    "Server=(localdb)\\MSSQLLocalDB;"
    "Database=BuzonAmbiental;"
    "Trusted_Connection=yes;"
)

def probar_conexion():
    try:
        conn = pyodbc.connect(conexion_cadena)
        cursor = conn.cursor()
        
        # Ejecutamos la consulta
        cursor.execute("SELECT @@VERSION")
        row = cursor.fetchone()
        
        # DIAGNÓSTICO: Verificamos si row es None antes de intentar leerlo
        if row is not None:
            print(f"¡Conexión exitosa! Versión de SQL: {row[0]}")
        else:
            print("La conexión funciona, pero la consulta no devolvió ninguna fila.")
            
        conn.close()
    except Exception as e:
        print(f"Error de conexión: {e}")

if __name__ == "__main__":
    probar_conexion()