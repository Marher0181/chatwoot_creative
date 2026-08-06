## COPIA Y PEGA ESTAS LÍNEAS EN LA TERMINAL DEL SERVER (una por una).
## Son comandos de bash, NO SQL suelto. Luego mándame screenshot del resultado.


## 1) VOLUMEN: cuántos mensajes hay y cuántos traen referral de anuncio

docker exec -i evolution-postgres psql -U evolution -d evolution -c "SELECT count(*) total, count(*) FILTER (WHERE message::text ILIKE '%externalAdReply%') con_referral FROM \"Message\";"


## 2) DESGLOSE por instancia y anuncio

docker exec -i evolution-postgres psql -U evolution -d evolution -c "SELECT i.name inst, ad->>'sourceId' ad_id, left(ad->>'title',22) anuncio, count(*) msgs, max(to_timestamp(m.\"messageTimestamp\"))::date ultimo FROM \"Message\" m JOIN \"Instance\" i ON i.id=m.\"instanceId\", LATERAL jsonb_path_query_first(m.message,'lax \$.**.externalAdReply') ad GROUP BY 1,2,3 ORDER BY msgs DESC LIMIT 15;"


## 3) BAJO QUÉ messageType viene el referral (define qué leer en n8n)

docker exec -i evolution-postgres psql -U evolution -d evolution -c "SELECT \"messageType\", count(*) FROM \"Message\" WHERE message::text ILIKE '%externalAdReply%' GROUP BY 1 ORDER BY 2 DESC;"


## 4) ÚLTIMOS 15 con los IDs de Chatwoot (para el PATCH desde n8n)

docker exec -i evolution-postgres psql -U evolution -d evolution -c "SELECT i.name inst, to_timestamp(m.\"messageTimestamp\")::date fecha, m.key->>'remoteJid' jid, m.key->>'fromMe' from_me, ad->>'sourceId' ad_id, m.\"chatwootConversationId\" cw_conv, m.\"chatwootInboxId\" cw_inbox FROM \"Message\" m JOIN \"Instance\" i ON i.id=m.\"instanceId\", LATERAL jsonb_path_query_first(m.message,'lax \$.**.externalAdReply') ad ORDER BY m.\"messageTimestamp\" DESC LIMIT 15;"
