# Parte II. Obtención de datos y diseño del modelo de conocimiento (1B)

## II.1 Obtención y caracterización de los datos

### Fuentes

| | Fuente 1 | Fuente 2 |
|---|---|---|
| Nombre | Traffic Crashes – Crashes | Traffic Crashes – People |
| Entidad responsable | City of Chicago – Chicago Police Department (formulario SR1050, IDOT) | City of Chicago – Chicago Police Department |
| Enlace | https://data.cityofchicago.org/d/85ca-t3if | https://data.cityofchicago.org/d/u6pd-qa9d |
| Formato | CSV (el portal también ofrece JSON, GeoJSON, XML, KML) | CSV (también JSON, XML, RDF/XML) |
| Mecanismo de obtención | Descarga directa (*Export → CSV*), 12/11/2026 | Descarga directa (*Export → CSV*), 12/11/2026 |
| Registros disponibles | 1 112 728 filas · 49 columnas | 2 441 932 filas · 29 columnas |
| Registros usados (tras ETL) | 318 383 accidentes | 599 999 personas |

### Campos seleccionados

| Fuente | Campo | Tipo | Descripción | Papel |
|---|---|---|---|---|
| Crashes | `CRASH_RECORD_ID` | texto (hash de 128 caracteres) | Identificador del accidente | Clave primaria |
| Crashes | `CRASH_DATE` | fecha-hora | Fecha y hora del accidente | Atributo |
| Crashes | `BEAT_OF_OCCURRENCE` | texto (4 dígitos) | Zona policial (beat) | Clave foránea a zona |
| Crashes | `LATITUDE`, `LONGITUDE` | decimal | Coordenadas WGS84 | Atributo geográfico |
| Crashes | `STREET_NAME` | texto | Calle | Atributo |
| Crashes | `FIRST_CRASH_TYPE` | texto (18 valores) | Tipo de primera colisión | Catálogo |
| People | `PERSON_ID` | texto (p. ej. O2431570) | Identificador de la persona | Clave primaria |
| People | `CRASH_RECORD_ID` | texto | Accidente al que pertenece | Clave foránea a Crashes |
| People | `PERSON_TYPE` | texto (6 valores) | Rol (conductor, pasajero, peatón…) | Catálogo |
| People | `AGE` | entero | Edad | Atributo |
| People | `SEX` | texto (M, F, X) | Sexo registrado | Atributo |
| People | `INJURY_CLASSIFICATION` | texto (5 valores) | Gravedad de la lesión | Catálogo |

**Relación entre fuentes:** `People.CRASH_RECORD_ID → Crashes.CRASH_RECORD_ID` (1 accidente : N personas).
En la muestra final hay en promedio 1,88 personas por accidente (mínimo 1, máximo 40).

### Problemas de calidad detectados

| Problema | Fuente / campo | Cantidad | Tratamiento |
|---|---|---|---|
| Edad faltante | People.`AGE` | 706 885 (28,9 %) | Fila eliminada |
| Edad = 0 (posible valor por defecto) | People.`AGE` | 5 158 en la muestra (0,9 %) | Se conserva; se señala para 1C |
| Sexo faltante o no válido | People.`SEX` | 42 199 (1,7 %) | Fila eliminada |
| Lesión faltante | People.`INJURY_CLASSIFICATION` | 828 | Fila eliminada |
| Coordenadas nulas, en 0 o fuera de Chicago | Crashes.`LATITUDE/LONGITUDE` | 8 806 (0,8 %) | Fila eliminada |
| Beat faltante | Crashes.`BEAT_OF_OCCURRENCE` | 5 | Fila eliminada |
| Calle faltante | Crashes.`STREET_NAME` | 1 | Fila eliminada |
| Formato de beat inconsistente (313 vs 0313) | Crashes.`BEAT_OF_OCCURRENCE` | — | Normalizado a 4 dígitos |
| Espacios y mayúsculas inconsistentes | campos de texto | — | Recorte y mayúsculas |
| Personas sin accidente válido | People | 15 343 | Eliminadas |
| Accidentes sin personas válidas | Crashes | 197 449 | Eliminados |
| Duplicados por clave | ambas | 0 | — |

Tras la limpieza quedaron 1 103 919 accidentes y 1 729 305 personas. Para mantener un volumen manejable se tomaron los
accidentes **más recientes** con **todas** sus personas hasta un tope de 600 000 personas:
**318 383 accidentes y 599 999 personas (19/05/2023 – 12/11/2026)**. Distribución por tipo de usuario: DRIVER 480 268,
PASSENGER 101 256, PEDESTRIAN 10 223, BICYCLE 7 651, NON-MOTOR VEHICLE 554, NON-CONTACT VEHICLE 47.

> Nota: eliminar las filas sin edad reduce sobre todo pasajeros y casos sin lesión, porque la policía suele omitir la edad
> en esos casos; debe tenerse en cuenta al interpretar proporciones.

## II.2 Modelo entidad-relación

*(insertar `modelos/mer_chicago.png`)*

| Entidad | Clave | Atributos |
|---|---|---|
| ACCIDENTE | `id_accidente` | fecha_hora, calle_nombre, latitud, longitud |
| PERSONA | `id_persona` | edad, sexo |
| ZONA_POLICIAL | `codigo_zona` | — |
| TIPO_PRIMER_IMPACTO | `nombre_impacto` | — |
| TIPO_USUARIO | `nombre_tipo` | — |
| CLASIFICACION_LESION | `nombre_lesion` | — |

| Relación | Cardinalidad | Lectura |
|---|---|---|
| OCURRE_EN | ZONA (0,N) – ACCIDENTE (1,1) | Todo accidente ocurre en una zona; una zona puede tener muchos o ningún accidente |
| INVOLUCRA | ACCIDENTE (1,N) – PERSONA (1,1) | Todo accidente tiene al menos una persona; cada persona pertenece a un solo accidente |
| TIENE_PRIMER_IMPACTO | ACCIDENTE (1,1) – TIPO (0,N) | |
| ES_DE_TIPO | PERSONA (1,1) – TIPO_USUARIO (0,N) | |
| TIENE_LESION | PERSONA (1,1) – CLASIFICACION (0,N) | |

**Decisiones de diseño**
- `ZONA_POLICIAL` se modela como entidad (y no como un texto del accidente) para poder agregar accidentes por zona y
  enlazarla más adelante con otras fuentes georreferenciadas.
- Los campos con valores controlados (`FIRST_CRASH_TYPE`, `PERSON_TYPE`, `INJURY_CLASSIFICATION`) se convierten en
  entidades-catálogo para evitar repetir texto y facilitar consultas por categoría.
- Las 49 y 29 columnas originales se reducen a las necesarias para las preguntas de competencia; no se copia la
  estructura de los archivos.
- La participación total (1,N) de ACCIDENTE en INVOLUCRA está garantizada por el ETL (se eliminaron accidentes sin personas).

## II.3 Esquema semántico RDF

*(insertar `rdf/esquema_rdf.png` · archivo: `rdf/esquema_vialchicago.ttl`)*

Espacio de nombres propio: `vial: <http://example.org/vialchicago#>`; recursos: `http://example.org/vialchicago/recurso/`.

**Clases**

| Clase | Superclase(s) | Origen |
|---|---|---|
| `vial:Accidente` | `dbo:Event`, `geo:Feature` | propia |
| `vial:Persona` | `foaf:Person` | propia |
| `vial:ZonaPolicial` | `geo:Feature` | propia |
| `vial:Catalogo` | `skos:Concept` | propia |
| `vial:TipoPrimerImpacto`, `vial:TipoUsuario`, `vial:ClasificacionLesion` | `vial:Catalogo` | propias |
| `geo:Geometry` | — | reutilizada |

**Propiedades de objeto**

| Propiedad | Dominio | Rango | Origen |
|---|---|---|---|
| `vial:ocurreEnZona` | Accidente | ZonaPolicial | propia |
| `vial:involucraPersona` / `vial:participaEn` (inversa) | Accidente / Persona | Persona / Accidente | propias |
| `vial:tipoPrimerImpacto` | Accidente | TipoPrimerImpacto | propia |
| `vial:tipoUsuario` | Persona | TipoUsuario | propia |
| `vial:clasificacionLesion` | Persona | ClasificacionLesion | propia |
| `geo:hasGeometry` | geo:Feature | geo:Geometry | reutilizada |

**Propiedades de datos**

| Propiedad | Dominio | Rango | Origen |
|---|---|---|---|
| `vial:idAccidente` ⊑ `dcterms:identifier` | Accidente | xsd:string | propia (subpropiedad) |
| `vial:idPersona` ⊑ `dcterms:identifier` | Persona | xsd:string | propia (subpropiedad) |
| `vial:codigoZona` ⊑ `dcterms:identifier` | ZonaPolicial | xsd:string | propia (subpropiedad) |
| `vial:fechaHora` ⊑ `dcterms:date` | Accidente | xsd:dateTime | propia (subpropiedad) |
| `vial:nombreCalle` | Accidente | xsd:string | propia |
| `vial:edad` | Persona | xsd:integer | propia |
| `schema:gender` | Persona | literal (M/F/X) | reutilizada |
| `skos:prefLabel` | Catalogo | literal | reutilizada |
| `geo:asWKT` | geo:Geometry | geo:wktLiteral | reutilizada |

**Jerarquías:** de clases (los tres catálogos bajo `vial:Catalogo` y este bajo `skos:Concept`) y de propiedades
(identificadores y fecha bajo Dublin Core).

**Decisión importante:** a los términos externos no se les redefine `rdfs:domain`. Si se declarara que
`dcterms:identifier` tiene dominio `vial:Accidente`, `vial:Persona` y `vial:ZonaPolicial` a la vez, un razonador RDFS
concluiría que todo recurso con identificador es al mismo tiempo accidente, persona y zona. Por eso se crean
subpropiedades propias con dominio específico que heredan el significado de Dublin Core.

**Archivos complementarios:** `rdf/catalogos.ttl` (los 29 valores de catálogo como `skos:Concept` agrupados en
`skos:ConceptScheme`) y `rdf/ejemplo_instancias.ttl` (un accidente con dos personas). Los tres archivos se validaron
con rdflib (145 + 87 + 27 tripletas) y responden consultas SPARQL de prueba.

## II.4 Vocabularios reutilizados

| Vocabulario | Prefijo | URI | Términos | Justificación |
|---|---|---|---|---|
| Dublin Core Terms | `dcterms` | `http://purl.org/dc/terms/` | `identifier`, `date` | Estándar para identificadores y fechas de recursos; nuestras propiedades de id y fecha son especializaciones |
| FOAF | `foaf` | `http://xmlns.com/foaf/0.1/` | `Person` | Una persona involucrada es una persona en sentido general; permite enlazar con otros datos de personas |
| SKOS | `skos` | `http://www.w3.org/2004/02/skos/core#` | `Concept`, `ConceptScheme`, `prefLabel`, `inScheme` | Los catálogos son vocabularios controlados, justo lo que SKOS representa |
| Schema.org | `schema` | `https://schema.org/` | `gender` | Propiedad ampliamente usada para el sexo/género de una persona |
| GeoSPARQL | `geo` | `http://www.opengis.net/ont/geosparql#` | `Feature`, `Geometry`, `hasGeometry`, `asWKT`, `wktLiteral` | Estándar OGC para datos espaciales; habilita consultas geográficas (distancias, zonas) en GraphDB |
| DBpedia Ontology | `dbo` | `http://dbpedia.org/ontology/` | `Event` | Un accidente es un suceso ocurrido en un momento y lugar |

Términos **propios** (sin equivalente adecuado): `vial:ZonaPolicial`, los tres catálogos, `vial:ocurreEnZona`,
`vial:involucraPersona`, `vial:tipoPrimerImpacto`, `vial:tipoUsuario`, `vial:clasificacionLesion`, `vial:nombreCalle`,
`vial:edad`. (`foaf:age` existe pero FOAF lo define como edad actual de un agente, no edad al momento de un evento.)

## II.5 Tabla de correspondencia

| Dato de origen | MER | Esquema RDF | Reutilizado / propio |
|---|---|---|---|
| crashes: `CRASH_RECORD_ID` | ACCIDENTE – id_accidente (PK) | `vial:Accidente` – `vial:idAccidente` (⊑ `dcterms:identifier`); también forma la URI del recurso | propio (subprop. de reutilizado) |
| crashes: `CRASH_DATE` | ACCIDENTE – fecha_hora | `vial:fechaHora` (⊑ `dcterms:date`), `xsd:dateTime` | propio (subprop. de reutilizado) |
| crashes: `STREET_NAME` | ACCIDENTE – calle_nombre | `vial:nombreCalle` | propio |
| crashes: `LATITUDE` + `LONGITUDE` | ACCIDENTE – latitud, longitud | `geo:hasGeometry` → `geo:Geometry` – `geo:asWKT` "POINT(lon lat)" | reutilizado |
| crashes: `BEAT_OF_OCCURRENCE` | ZONA_POLICIAL – codigo_zona (PK); relación OCURRE_EN | `vial:ZonaPolicial` – `vial:codigoZona`; `vial:ocurreEnZona` | propio |
| crashes: `FIRST_CRASH_TYPE` | TIPO_PRIMER_IMPACTO – nombre_impacto; relación TIENE_PRIMER_IMPACTO | `vial:TipoPrimerImpacto` – `skos:prefLabel`; `vial:tipoPrimerImpacto` | clase/propiedad propia + `skos:prefLabel` reutilizado |
| people: `PERSON_ID` | PERSONA – id_persona (PK) | `vial:Persona` (⊑ `foaf:Person`) – `vial:idPersona` | propio (subprop. de reutilizado) |
| people: `CRASH_RECORD_ID` | relación INVOLUCRA (FK) | `vial:involucraPersona` / `vial:participaEn` | propio |
| people: `AGE` | PERSONA – edad | `vial:edad`, `xsd:integer` | propio |
| people: `SEX` | PERSONA – sexo | `schema:gender` | reutilizado |
| people: `PERSON_TYPE` | TIPO_USUARIO – nombre_tipo; relación ES_DE_TIPO | `vial:TipoUsuario` – `skos:prefLabel`; `vial:tipoUsuario` | propio + `skos:prefLabel` |
| people: `INJURY_CLASSIFICATION` | CLASIFICACION_LESION – nombre_lesion; relación TIENE_LESION | `vial:ClasificacionLesion` – `skos:prefLabel`; `vial:clasificacionLesion` | propio + `skos:prefLabel` |

## II.6 Conclusiones y dificultades

**Conclusiones**
- Las dos fuentes son reales, abiertas y se enlazan sin ambigüedad por `CRASH_RECORD_ID`, lo que confirma la viabilidad
  planteada en 1A.
- El MER separa los catálogos y la zona policial como entidades, lo que se traduce directamente en clases SKOS y
  GeoSPARQL en el esquema RDF.
- Se reutilizan seis vocabularios abiertos donde existe correspondencia real; los conceptos específicos del dominio
  vial se definen en un espacio de nombres propio.

**Dificultades**
- Volumen: los CSV originales pesan ~700 MB y ~830 MB; se usó `data.table::fread` leyendo solo las columnas necesarias
  y los resultados se comprimieron para subirlos a GitHub (límite de 100 MB por archivo).
- Calidad: casi el 29 % de las personas no tiene edad, y existen edades 0 sospechosas; se priorizó un conjunto sin nulos,
  a costa de un posible sesgo hacia conductores.
- Formatos: fechas en formato `MM/DD/YYYY hh:mm:ss AM/PM` y beats sin ceros a la izquierda requirieron normalización.
- Modelado: evitar redefinir dominios de términos ajenos obligó a crear subpropiedades propias.
