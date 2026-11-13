# Datos originales

Los archivos completos **no se suben al repositorio** por su tamaño (≈700 MB y ≈830 MB; GitHub admite máximo 100 MB por archivo).
Aquí solo hay una muestra de 200 filas de cada uno, con todas sus columnas, para revisar la estructura original.

| Archivo descargado | Fuente | Página | Descarga directa CSV | Filas | Columnas |
|---|---|---|---|---|---|
| `Traffic_Crashes_-_Crashes_20261112.csv` | Traffic Crashes – Crashes | https://data.cityofchicago.org/d/85ca-t3if | https://data.cityofchicago.org/api/v3/views/85ca-t3if/export.csv?accessType=DOWNLOAD | 1 112 728 | 49 |
| `Traffic_Crashes_-_People_20261112.csv` | Traffic Crashes – People | https://data.cityofchicago.org/d/u6pd-qa9d | https://data.cityofchicago.org/api/v3/views/u6pd-qa9d/export.csv?accessType=DOWNLOAD | 2 441 932 | 29 |

- Entidad responsable: City of Chicago (datos registrados por el Chicago Police Department en el formulario SR1050 de IDOT).
- Mecanismo de obtención: descarga directa desde el portal (*Export → CSV*). El portal también ofrece API (Socrata/SODA) en JSON, GeoJSON y XML.
- Fecha de descarga: 12/11/2026.

Para reproducir el ETL, guardar ambos archivos con esos nombres y ajustar las rutas al inicio de `scripts/etl_chicago.R`.

**Copia de los archivos completos (Google Drive del grupo):**
https://drive.google.com/drive/folders/1FU8YSVvBafAudHL5fMt_gFuzPCuM_T7V?usp=sharing
