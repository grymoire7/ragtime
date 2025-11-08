CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "models" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "model_id" varchar NOT NULL, "name" varchar NOT NULL, "provider" varchar NOT NULL, "family" varchar, "model_created_at" datetime(6), "context_window" integer, "max_output_tokens" integer, "knowledge_cutoff" date, "modalities" json DEFAULT '{}', "capabilities" json DEFAULT '[]', "pricing" json DEFAULT '{}', "metadata" json DEFAULT '{}', "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_models_on_provider_and_model_id" ON "models" ("provider", "model_id") /*application='Ragtime'*/;
CREATE INDEX "index_models_on_provider" ON "models" ("provider") /*application='Ragtime'*/;
CREATE INDEX "index_models_on_family" ON "models" ("family") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "chats" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "model_id" integer, CONSTRAINT "fk_rails_1835d93df1"
FOREIGN KEY ("model_id")
  REFERENCES "models" ("id")
);
CREATE INDEX "index_chats_on_model_id" ON "chats" ("model_id") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "tool_calls" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "tool_call_id" varchar NOT NULL, "name" varchar NOT NULL, "arguments" json DEFAULT '{}', "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "message_id" integer NOT NULL, CONSTRAINT "fk_rails_9c8daee481"
FOREIGN KEY ("message_id")
  REFERENCES "messages" ("id")
);
CREATE UNIQUE INDEX "index_tool_calls_on_tool_call_id" ON "tool_calls" ("tool_call_id") /*application='Ragtime'*/;
CREATE INDEX "index_tool_calls_on_name" ON "tool_calls" ("name") /*application='Ragtime'*/;
CREATE INDEX "index_tool_calls_on_message_id" ON "tool_calls" ("message_id") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "messages" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "role" varchar NOT NULL, "content" text, "input_tokens" integer, "output_tokens" integer, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "chat_id" integer NOT NULL, "model_id" integer, "tool_call_id" integer, "metadata" json DEFAULT '{}' /*application='Ragtime'*/, CONSTRAINT "fk_rails_c02b47ad97"
FOREIGN KEY ("model_id")
  REFERENCES "models" ("id")
, CONSTRAINT "fk_rails_0f670de7ba"
FOREIGN KEY ("chat_id")
  REFERENCES "chats" ("id")
, CONSTRAINT "fk_rails_552873cb52"
FOREIGN KEY ("tool_call_id")
  REFERENCES "tool_calls" ("id")
);
CREATE INDEX "index_messages_on_role" ON "messages" ("role") /*application='Ragtime'*/;
CREATE INDEX "index_messages_on_chat_id" ON "messages" ("chat_id") /*application='Ragtime'*/;
CREATE INDEX "index_messages_on_model_id" ON "messages" ("model_id") /*application='Ragtime'*/;
CREATE INDEX "index_messages_on_tool_call_id" ON "messages" ("tool_call_id") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "active_storage_blobs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "filename" varchar NOT NULL, "content_type" varchar, "metadata" text, "service_name" varchar NOT NULL, "byte_size" bigint NOT NULL, "checksum" varchar, "created_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_active_storage_blobs_on_key" ON "active_storage_blobs" ("key") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "active_storage_attachments" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "record_type" varchar NOT NULL, "record_id" bigint NOT NULL, "blob_id" bigint NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c3b3935057"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE INDEX "index_active_storage_attachments_on_blob_id" ON "active_storage_attachments" ("blob_id") /*application='Ragtime'*/;
CREATE UNIQUE INDEX "index_active_storage_attachments_uniqueness" ON "active_storage_attachments" ("record_type", "record_id", "name", "blob_id") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "active_storage_variant_records" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "blob_id" bigint NOT NULL, "variation_digest" varchar NOT NULL, CONSTRAINT "fk_rails_993965df05"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE UNIQUE INDEX "index_active_storage_variant_records_uniqueness" ON "active_storage_variant_records" ("blob_id", "variation_digest") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "documents" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "title" varchar, "filename" varchar, "content_type" varchar, "file_size" integer, "status" varchar, "processed_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "error_message" text /*application='Ragtime'*/);
CREATE INDEX "index_documents_on_status" ON "documents" ("status") /*application='Ragtime'*/;
CREATE INDEX "index_documents_on_created_at" ON "documents" ("created_at") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "chunks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "document_id" integer NOT NULL, "content" text, "position" integer, "token_count" integer, "embedding" blob, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_1dac2f17d2"
FOREIGN KEY ("document_id")
  REFERENCES "documents" ("id")
);
CREATE INDEX "index_chunks_on_document_id" ON "chunks" ("document_id") /*application='Ragtime'*/;
CREATE INDEX "index_chunks_on_position" ON "chunks" ("position") /*application='Ragtime'*/;
CREATE VIRTUAL TABLE vec_chunks USING vec0(
            chunk_id INTEGER PRIMARY KEY,
            embedding FLOAT[512]
          );
CREATE TABLE IF NOT EXISTS "vec_chunks_info" (key text primary key, value any);
CREATE TABLE IF NOT EXISTS "vec_chunks_chunks"(chunk_id INTEGER PRIMARY KEY AUTOINCREMENT,size INTEGER NOT NULL,validity BLOB NOT NULL,rowids BLOB NOT NULL);
CREATE TABLE IF NOT EXISTS "vec_chunks_rowids"(rowid INTEGER PRIMARY KEY AUTOINCREMENT,id,chunk_id INTEGER,chunk_offset INTEGER);
CREATE TABLE IF NOT EXISTS "vec_chunks_vector_chunks00"(rowid PRIMARY KEY,vectors BLOB NOT NULL);
CREATE TABLE IF NOT EXISTS "solid_queue_jobs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "queue_name" varchar NOT NULL, "class_name" varchar NOT NULL, "arguments" text, "priority" integer DEFAULT 0 NOT NULL, "active_job_id" varchar, "scheduled_at" datetime(6), "finished_at" datetime(6), "concurrency_key" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_solid_queue_jobs_on_active_job_id" ON "solid_queue_jobs" ("active_job_id") /*application='Ragtime'*/;
CREATE INDEX "index_solid_queue_jobs_on_class_name" ON "solid_queue_jobs" ("class_name") /*application='Ragtime'*/;
CREATE INDEX "index_solid_queue_jobs_on_finished_at" ON "solid_queue_jobs" ("finished_at") /*application='Ragtime'*/;
CREATE INDEX "index_solid_queue_jobs_for_filtering" ON "solid_queue_jobs" ("queue_name", "finished_at") /*application='Ragtime'*/;
CREATE INDEX "index_solid_queue_jobs_for_alerting" ON "solid_queue_jobs" ("scheduled_at", "finished_at") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_pauses" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "queue_name" varchar NOT NULL, "created_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_solid_queue_pauses_on_queue_name" ON "solid_queue_pauses" ("queue_name") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_processes" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "kind" varchar NOT NULL, "last_heartbeat_at" datetime(6) NOT NULL, "supervisor_id" bigint, "pid" integer NOT NULL, "hostname" varchar, "metadata" text, "created_at" datetime(6) NOT NULL, "name" varchar NOT NULL);
CREATE INDEX "index_solid_queue_processes_on_last_heartbeat_at" ON "solid_queue_processes" ("last_heartbeat_at") /*application='Ragtime'*/;
CREATE UNIQUE INDEX "index_solid_queue_processes_on_name_and_supervisor_id" ON "solid_queue_processes" ("name", "supervisor_id") /*application='Ragtime'*/;
CREATE INDEX "index_solid_queue_processes_on_supervisor_id" ON "solid_queue_processes" ("supervisor_id") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_recurring_tasks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "schedule" varchar NOT NULL, "command" varchar(2048), "class_name" varchar, "arguments" text, "queue_name" varchar, "priority" integer DEFAULT 0, "static" boolean DEFAULT 1 NOT NULL, "description" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_solid_queue_recurring_tasks_on_key" ON "solid_queue_recurring_tasks" ("key") /*application='Ragtime'*/;
CREATE INDEX "index_solid_queue_recurring_tasks_on_static" ON "solid_queue_recurring_tasks" ("static") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_semaphores" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "value" integer DEFAULT 1 NOT NULL, "expires_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_solid_queue_semaphores_on_expires_at" ON "solid_queue_semaphores" ("expires_at") /*application='Ragtime'*/;
CREATE INDEX "index_solid_queue_semaphores_on_key_and_value" ON "solid_queue_semaphores" ("key", "value") /*application='Ragtime'*/;
CREATE UNIQUE INDEX "index_solid_queue_semaphores_on_key" ON "solid_queue_semaphores" ("key") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_blocked_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "queue_name" varchar NOT NULL, "priority" integer DEFAULT 0 NOT NULL, "concurrency_key" varchar NOT NULL, "expires_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_4cd34e2228"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE INDEX "index_solid_queue_blocked_executions_for_release" ON "solid_queue_blocked_executions" ("concurrency_key", "priority", "job_id") /*application='Ragtime'*/;
CREATE INDEX "index_solid_queue_blocked_executions_for_maintenance" ON "solid_queue_blocked_executions" ("expires_at", "concurrency_key") /*application='Ragtime'*/;
CREATE UNIQUE INDEX "index_solid_queue_blocked_executions_on_job_id" ON "solid_queue_blocked_executions" ("job_id") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_claimed_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "process_id" bigint, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_9cfe4d4944"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE UNIQUE INDEX "index_solid_queue_claimed_executions_on_job_id" ON "solid_queue_claimed_executions" ("job_id") /*application='Ragtime'*/;
CREATE INDEX "index_solid_queue_claimed_executions_on_process_id_and_job_id" ON "solid_queue_claimed_executions" ("process_id", "job_id") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_failed_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "error" text, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_39bbc7a631"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE UNIQUE INDEX "index_solid_queue_failed_executions_on_job_id" ON "solid_queue_failed_executions" ("job_id") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_ready_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "queue_name" varchar NOT NULL, "priority" integer DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_81fcbd66af"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE UNIQUE INDEX "index_solid_queue_ready_executions_on_job_id" ON "solid_queue_ready_executions" ("job_id") /*application='Ragtime'*/;
CREATE INDEX "index_solid_queue_poll_all" ON "solid_queue_ready_executions" ("priority", "job_id") /*application='Ragtime'*/;
CREATE INDEX "index_solid_queue_poll_by_queue" ON "solid_queue_ready_executions" ("queue_name", "priority", "job_id") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_recurring_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "task_key" varchar NOT NULL, "run_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_318a5533ed"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE UNIQUE INDEX "index_solid_queue_recurring_executions_on_job_id" ON "solid_queue_recurring_executions" ("job_id") /*application='Ragtime'*/;
CREATE UNIQUE INDEX "index_solid_queue_recurring_executions_on_task_key_and_run_at" ON "solid_queue_recurring_executions" ("task_key", "run_at") /*application='Ragtime'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_scheduled_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "queue_name" varchar NOT NULL, "priority" integer DEFAULT 0 NOT NULL, "scheduled_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c4316f352d"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE UNIQUE INDEX "index_solid_queue_scheduled_executions_on_job_id" ON "solid_queue_scheduled_executions" ("job_id") /*application='Ragtime'*/;
CREATE INDEX "index_solid_queue_dispatch_all" ON "solid_queue_scheduled_executions" ("scheduled_at", "priority", "job_id") /*application='Ragtime'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20251107201712'),
('20251104164359'),
('20251102221021'),
('20251029214244'),
('20251029205413'),
('20251029171638'),
('20251029171637'),
('20251029171636'),
('20251029171635'),
('20251029171634'),
('20251029171633');

