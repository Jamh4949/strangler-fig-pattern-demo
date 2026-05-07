# CAUSA RAÍZ: Herencia de Plantilla Qute Rota

## EL PROBLEMA

El archivo `quarkus-owner-service/src/main/resources/templates/ownersList.html` tenía HTML y `<link>`/`<style>` ANTES del `{#include page.html}`. En Qute, esto significa que:

1. **HTML crudo previo al include es ignorado** → Los `<link>` y `<style>` nunca llegan al `<head>` del HTML final
2. **El navegador recibe solo la estructura de `page.html`** → sin los estilos modernos incrustados
3. **Los cambios CSS nunca se aplican** → aunque la compilación y el build sean exitosos

### Estructura Incorrecta (Lo que había):
```html
{@tipos...}
<link href="...">          ❌ Ignorado por Qute
<style>...</style>         ❌ Ignorado por Qute
{#include page.html}
{#title}...{/title}
{#content}...{/content}
{/include}
```

### Estructura Correcta (Lo que debe ser):
```html
{@tipos...}
{#include page.html}       ✅ Inicia la herencia
{#title}...{/title}
{#content}
  <!-- HTML y estilos van AQUÍ, dentro del content -->
{/content}
{/include}
```

---

## LA SOLUCIÓN

### Paso 1: Recompilar el Microservicio Quarkus

Desde el directorio raíz del proyecto:

```bash
cd quarkus-owner-service
bash ./mvnw clean package -DskipTests -o /dev/null 2>&1
cd ..
```

**¿Por qué?** Esto genera un nuevo `target/quarkus-app/` con los templates correctos en el classpath. El archivo `ownersList.html` ahora tiene la estructura Qute válida.

### Paso 2: Reconstruir la Imagen Docker (Sin caché)

```bash
docker-compose build --no-cache quarkus-owner-service
```

**¿Por qué?** Fuerza a Docker a copiar los archivos recién compilados del `target/` a la imagen sin reutilizar capas antiguas.

### Paso 3: Levantar el Contenedor Limpio

```bash
docker-compose up -d --force-recreate quarkus-owner-service
```

**¿Por qué?** Mata el contenedor viejo, inicia uno nuevo con la imagen actualizada.

### Paso 4: Reiniciar kstreams para forzar sincronización

```bash
docker-compose restart kstreams-table-joiner
```

**¿Por qué?** Asegura que la tabla join de Kafka está actualizada y lista para servir datos a Quarkus.

---

## VERIFICACIÓN

### Por navegador:
- Accede a: `http://localhost/petclinic/owners.html` (si estás en read_write)
- O: `http://localhost:8080/owners/` (directo a Quarkus)
- **Deberías ver**:
  - Navbar moderno con logo "Q" y fondo dark
  - Tarjetas (cards) elegantes con efecto glassmorphism
  - Color azul cian (#4cc9f0) y púrpura (#7c3aed)
  - Badge "MODERNIZADO - QUARKUS SERVICE"
  - Fuente Inter moderna

### Por terminal (curl):
```bash
curl -s 'http://localhost:8080/owners/' | head -50 | grep -E "navbar-modern|glass-panel|MODERNIZADO|4cc9f0"
```

Si ves esas clases y colores, el frontend está actualizado ✅

---

## ¿POR QUÉ NO FUNCIONABA ANTES?

**Rastreo del flujo de la request**:

1. **Navegador** → solicita `/owners/`
2. **NGINX** → (read_write.conf) reescribe a `/owners/` y redirige a `http://quarkus-owner-service:8080`
3. **Quarkus (OwnerResource.java)** → método `getOwners()` inyecta `Template ownersList` y renderiza
4. **Motor Qute** → busca `templates/ownersList.html` en el classpath
5. **PROBLEMA**: El HTML crudo ANTES del `{#include}` se descarta. Solo se procesa lo DENTRO de `{#title}` y `{#content}`
6. **Resultado**: Se servía el layout de `page.html` VIEJO (sin estilos modernos) porque los `<link>` del ownersList nunca llegaban al `<head>`

---

## ARCHIVOS MODIFICADOS

- ✅ `quarkus-owner-service/src/main/resources/templates/ownersList.html` → **Estructura Qute corregida**
- ✅ `quarkus-owner-service/src/main/resources/templates/page.html` → **Ya tiene Bootstrap 5.3.3 y estilos modernos**

---

## COMANDO TODO EN UNO (si prefieres una sola línea)

```bash
cd quarkus-owner-service && bash ./mvnw clean package -DskipTests > /dev/null 2>&1 && cd .. && docker-compose build --no-cache quarkus-owner-service && docker-compose up -d --force-recreate quarkus-owner-service && docker-compose restart kstreams-table-joiner && echo "✅ Deployment completado. Accede a http://localhost/petclinic/owners.html para ver el nuevo diseño."
```

---

## RESUMEN ARQUITECTÓNICO

Este es un ejemplo **perfecto del Strangler Pattern**:

- **Monolito (Spring PetClinic)**: UI vieja, Bootstrap 4, sin cambios
- **Microservicio (Quarkus)**: UI moderna, Bootstrap 5.3 + glassmorphism, diseño totalmente diferente
- **NGINX (Proxy)**: Ruteo quirúrgico → los requests de `/owners` van SOLO a Quarkus
- **CDC (Change Data Capture)**: Kafka + MongoDB synca datos de MySQL → Quarkus

El contraste visual es **DRÁSTICO** por diseño: no se parece en nada. Eso es el Strangler Pattern en acción.
