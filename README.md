# Datos-PROYECTO-BIMESTRE-1-7C
## Seguridad vial en Chicago – Grafo de conocimiento

Práctica bimestral · **Explotación de datos en ecosistemas heterogéneos** · UTPL
Entrega actual: **1B – Obtención de datos y diseño del modelo de conocimiento**

> Integrantes: _(completar)_
> Docente: _(completar)_

---

## 1. Descripción

Proyecto de ciudades inteligentes que analiza los **accidentes de tránsito de Chicago** y las **personas involucradas**
para responder dónde, cuándo y cómo ocurren los siniestros y quiénes resultan lesionados.
Los datos provienen del Portal de Datos Abiertos de la Ciudad de Chicago y se modelan con un MER y un esquema RDF que
reutiliza vocabularios abiertos (Dublin Core, FOAF, SKOS, Schema.org, GeoSPARQL y DBpedia Ontology).

## 2. Estructura del repositorio

```
Datos-PROYECTO-BIMESTRE-1-7C/
├── README.md                              ← guía del repositorio (este archivo)
├── datos/
│   ├── originales/
│   │   ├── README.md                      ← enlaces de descarga y carpeta de Drive con los CSV completos
│   │   ├── crashes_original_muestra.csv   ← 200 filas, 49 columnas originales
│   │   └── people_original_muestra.csv    ← 200 filas, 29 columnas originales
│   ├── procesados/
│   │   ├── crashes_limpio.zip             ← 318 383 accidentes (salida del ETL)
│   │   ├── people_limpio.zip              ← 599 999 personas   (salida del ETL)
│   │   ├── crashes_people_unido.zip       ← persona + datos de su accidente (599 999 filas)
│   │   └── calidad_etl.csv                ← métricas de calidad: nulos, duplicados y filas por etapa
│   └── muestras/
│       ├── crashes_muestra.csv            ← 1 000 filas del CSV limpio (se ve directo en GitHub)
│       └── people_muestra.csv             ← 1 000 filas del CSV limpio
├── modelos/
│   └── mer_chicago.png                    ← diagrama del modelo entidad-relación
├── rdf/
│   ├── esquema_vialchicago.ttl            ← ESQUEMA SEMÁNTICO (clases y propiedades)
│   ├── catalogos.ttl                      ← valores SKOS de los catálogos (impacto, tipo de usuario, lesión)
│   ├── ejemplo_instancias.ttl             ← 1 accidente + 2 personas, solo ilustrativo
│   └── esquema_rdf.png                    ← diagrama del esquema RDF
├── scripts/
│   ├── etl_chicago.R                      ← limpieza, filtrado y muestreo (genera datos/procesados)
│   └── generar_catalogos.py               ← genera rdf/catalogos.ttl y rdf/ejemplo_instancias.ttl
└── docs/
    └── informe_parte_II.md                ← texto de la Parte II del informe (1B)
```

> Los CSV limpios van comprimidos en `.zip` porque GitHub no acepta archivos de más de 100 MB
> (`people_limpio.csv` pesa 105 MB y la unión 153 MB). Los CSV originales completos (~700 MB y ~830 MB) están en
> [Google Drive](https://drive.google.com/drive/folders/1FU8YSVvBafAudHL5fMt_gFuzPCuM_T7V?usp=sharing).

## 3. Fuentes de datos

| Fuente | Responsable | Enlace | Formato | Registros originales | Registros usados |
|---|---|---|---|---|---|
| Traffic Crashes – Crashes | City of Chicago / Chicago Police Department | https://data.cityofchicago.org/d/85ca-t3if | CSV (también JSON, GeoJSON, XML) | 1 112 728 | 318 383 |
| Traffic Crashes – People | City of Chicago / Chicago Police Department | https://data.cityofchicago.org/d/u6pd-qa9d | CSV (también JSON, XML) | 2 441 932 | 599 999 |

Las dos fuentes se relacionan por **`CRASH_RECORD_ID`** (un accidente → una o más personas).
Obtención: descarga directa desde el portal (*Export → CSV*) el 12/11/2026.

## 4. Cómo reproducir

1. Descargar los dos CSV completos (ver [`datos/originales/README.md`](datos/originales/README.md)).
2. Ejecutar el ETL en R:
   ```r
   install.packages(c("data.table", "lubridate"))
   source("scripts/etl_chicago.R")   # ajustar RUTA_CRASHES, RUTA_PEOPLE y SALIDA al inicio del script
   ```
3. (Opcional) Regenerar los catálogos RDF (Python 3 + `pandas`):
   ```bash
   python scripts/generar_catalogos.py crashes_limpio.csv people_limpio.csv rdf
   ```
4. Validar los `.ttl` con `rdflib`, Protégé o cargándolos en GraphDB.

### Reglas del ETL
- Solo las columnas del modelo: 7 de Crashes y 6 de People.
- Sin duplicados por clave y sin nulos en esas columnas.
- Coordenadas fuera de Chicago (lat 41.6–42.1, lon −87.95 a −87.5) o en 0 se tratan como nulas.
- `BEAT_OF_OCCURRENCE` normalizado a 4 dígitos; edades fuera de 0–110 y sexo distinto de M/F/X se tratan como nulos.
- Solo registros relacionados: toda persona tiene su accidente y todo accidente al menos una persona.
- Muestra: accidentes **más recientes** con **todas** sus personas, hasta 600 000 personas (19/05/2023 – 12/11/2026).

## 5. Modelo de conocimiento (resumen)

**MER** – Entidades: `ACCIDENTE`, `PERSONA`, `ZONA_POLICIAL`, `TIPO_PRIMER_IMPACTO`, `TIPO_USUARIO`, `CLASIFICACION_LESION`.
Un accidente *involucra* (1,N) personas, ocurre en (1,1) zona policial y tiene (1,1) tipo de primer impacto.

**Esquema RDF** – espacio de nombres propio `vial: <http://example.org/vialchicago#>`.

| Vocabulario | Prefijo | Namespace | Términos reutilizados |
|---|---|---|---|
| Dublin Core Terms | `dcterms:` | `http://purl.org/dc/terms/` | `identifier`, `date` (como superpropiedades) |
| FOAF | `foaf:` | `http://xmlns.com/foaf/0.1/` | `Person` |
| SKOS | `skos:` | `http://www.w3.org/2004/02/skos/core#` | `Concept`, `ConceptScheme`, `prefLabel`, `inScheme` |
| Schema.org | `schema:` | `https://schema.org/` | `gender` |
| GeoSPARQL | `geo:` | `http://www.opengis.net/ont/geosparql#` | `Feature`, `Geometry`, `hasGeometry`, `asWKT`, `wktLiteral` |
| DBpedia Ontology | `dbo:` | `http://dbpedia.org/ontology/` | `Event` |

Justificación, tabla de correspondencia y calidad de datos: [`docs/informe_parte_II.md`](docs/informe_parte_II.md).

## 6. Enlaces directos (para el informe)

- Datos procesados: https://github.com/Steven2610/Datos-PROYECTO-BIMESTRE-1-7C/tree/main/datos/procesados
- Diagrama MER: https://github.com/Steven2610/Datos-PROYECTO-BIMESTRE-1-7C/blob/main/modelos/mer_chicago.png
- Diagrama RDF: https://github.com/Steven2610/Datos-PROYECTO-BIMESTRE-1-7C/blob/main/rdf/esquema_rdf.png
- Esquema Turtle: https://github.com/Steven2610/Datos-PROYECTO-BIMESTRE-1-7C/blob/main/rdf/esquema_vialchicago.ttl
- Script ETL: https://github.com/Steven2610/Datos-PROYECTO-BIMESTRE-1-7C/blob/main/scripts/etl_chicago.R

## 7. Estado

- [x] 1A – Definición del problema, preguntas de competencia y fuentes
- [x] 1B – Obtención de datos, MER y esquema RDF
- [ ] 1C – Transformación a tripletas e implementación del grafo en GraphDB
