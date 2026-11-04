import { parentPort } from "node:worker_threads";
import { runJob, type Job } from "./generate-one.ts";

parentPort!.on("message", (job: Job) => {
  try { parentPort!.postMessage({ ok: true, result: runJob(job) }); }
  catch (e) { parentPort!.postMessage({ ok: false, index: job.index, error: (e as Error).stack }); }
});
