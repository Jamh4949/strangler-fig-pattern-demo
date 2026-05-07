#!/bin/bash

# ============================================================================
# COMANDO ÚNICO DE REGISTRACIÓN DE CONECTORES KAFKA CONNECT
# Registra los dos conectores CDC necesarios para sincronizar datos MySQL→MongoDB
# ============================================================================

# Asegúrate de que Kafka Connect está disponible en http://localhost:8083
# (o la URL donde lo tengas expuesto)

CONNECT_URL="http://localhost:8083"

echo "=================================================="
echo "📡 REGISTRANDO CONECTORES KAFKA CONNECT"
echo "=================================================="
echo ""

# 1. Registrar el Source Connector (MySQL → Kafka)
echo "1️⃣  Registrando MySQL Source Connector (CDC Debezium)..."
echo "   Conectador: petclinic-owners-pets-mysql-src-001"
echo "   Tablas: petclinic.owners, petclinic.pets"
echo ""

curl -X POST "$CONNECT_URL/connectors" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "petclinic-owners-pets-mysql-src-001",
    "config": {
      "connector.class": "io.debezium.connector.mysql.MySqlConnector",
      "key.converter": "org.apache.kafka.connect.json.JsonConverter",
      "key.converter.schemas.enable": false,
      "value.converter": "org.apache.kafka.connect.json.JsonConverter",
      "value.converter.schemas.enable": false,
      "tasks.max": "1",
      "database.hostname": "mysql",
      "database.port": "3306",
      "database.user": "root",
      "database.password": "debezium",
      "database.server.id": "12345",
      "database.server.name": "mysql1",
      "database.include": "petclinic",
      "table.include.list": "petclinic.owners,petclinic.pets",
      "database.history.kafka.bootstrap.servers": "kafka:9092",
      "database.history.kafka.topic": "schema-changes.petclinic"
    }
  }' && echo "" && echo "✓ MySQL Source Connector registrado" || echo "✗ Error al registrar MySQL Source"

echo ""
sleep 2
echo ""

# 2. Registrar el Sink Connector (Kafka → MongoDB)
echo "2️⃣  Registrando MongoDB Sink Connector..."
echo "   Conectador: petclinic-owners-pets-mongodb-sink-001"
echo "   Topic: kstreams.owners-with-pets"
echo ""

curl -X POST "$CONNECT_URL/connectors" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "petclinic-owners-pets-mongodb-sink-001",
    "config": {
      "topics": "kstreams.owners-with-pets",
      "connector.class": "com.mongodb.kafka.connect.MongoSinkConnector",
      "key.converter": "org.apache.kafka.connect.storage.StringConverter",
      "value.converter": "org.apache.kafka.connect.json.JsonConverter",
      "value.converter.schemas.enable": false,
      "tasks.max": "1",
      "connection.uri": "mongodb://mongodb:27017",
      "database": "petclinic",
      "document.id.strategy": "com.mongodb.kafka.connect.sink.processor.id.strategy.ProvidedInKeyStrategy",
      "post.processor.chain": "com.mongodb.kafka.connect.sink.processor.BlockListValueProjector,com.mongodb.kafka.connect.sink.processor.field.renaming.RenameByMapping",
      "field.renamer.mapping": "[{\"oldName\":\"value.owner.id\", \"newName\":\"owner_id\"}]",
      "value.projection.type": "BlockList",
      "value.projection.list": "pets.id,pets.owner_id,pets.birth_date,pets.type_id",
      "transforms": "createkey,flatkey,renameid",
      "transforms.createkey.type": "org.apache.kafka.connect.transforms.ValueToKey",
      "transforms.createkey.fields": "owner",
      "transforms.flatkey.type": "org.apache.kafka.connect.transforms.Flatten$Key",
      "transforms.flatkey.delimiter": "_",
      "transforms.renameid.type": "org.apache.kafka.connect.transforms.ReplaceField$Key",
      "transforms.renameid.renames": "owner_id:_id"
    }
  }' && echo "" && echo "✓ MongoDB Sink Connector registrado" || echo "✗ Error al registrar MongoDB Sink"

echo ""
echo "=================================================="
echo "✅ AMBOS CONECTORES REGISTRADOS"
echo "=================================================="
echo ""
echo "📊 Próximas acciones:"
echo "   1. Los datos de petclinic.owners y petclinic.pets"
echo "      serán capturados por Debezium desde MySQL"
echo ""
echo "   2. Se publicarán en Kafka como eventos CDC"
echo ""
echo "   3. kstreams-table-joiner los procesará"
echo ""
echo "   4. Se escribirán en MongoDB con el formato"
echo "      esperado por el microservicio Quarkus"
echo ""
echo "⏱️  Espera 30-60 segundos a que la sincronización complete"
echo ""
echo "🔍 Verifica el estado de los conectores:"
echo "   curl http://localhost:8083/connectors"
echo ""
