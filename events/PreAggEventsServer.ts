import express from "express";
import type { OrchestratorApi } from "../packages/cubejs-server-core/src/core/OrchestratorApi";
import type { Request, Response } from "express";

type StartOpts = {
  port?: number;
  token?: string; // simple auth par header
  path?: string; // endpoint SSE
};

export function startPreAggEventsServer(
  orchestratorApi: OrchestratorApi,
  opts: StartOpts = {}
) {
  const port = opts.port ?? Number(process.env.CUBEJS_EVENTS_PORT || 5555);
  const path = opts.path ?? "/events/pre-aggregations";
  const token = opts.token ?? process.env.CUBEJS_EVENTS_TOKEN;

  const app = express();

  // Auth très simple par header (optionnel, mais conseillé en prod)
  app.use((req, res, next) => {
    if (!token) return next();
    const got = req.header("x-internal-token");
    if (got !== token) return res.status(401).json({ error: "unauthorized" });
    next();
  });

  app.get(path, async (req: Request, res: Response) => {
    const dataSource =
      (typeof req.query.dataSource === "string" && req.query.dataSource) ||
      "default";

    res.status(200);
    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache, no-transform");
    res.setHeader("Connection", "keep-alive");
    (res as any).flushHeaders?.();

    // abonnement au bus de jobs (exposé par QueryOrchestrator -> QueryQueue)
    const off = await orchestratorApi.onPreAggregationJobEvent((evt: any) => {
      // force ds si manquant
      const payload = JSON.stringify({
        ...evt,
        dataSource: evt.dataSource || dataSource,
      });
      res.write(`event: preagg\n`);
      res.write(`data: ${payload}\n\n`);
    }, dataSource);

    // keep-alive
    const ka = setInterval(() => res.write(`: ping\n\n`), 15000);

    req.on("close", () => {
      clearInterval(ka);
      try {
        off?.();
      } catch {}
      try {
        res.end();
      } catch {}
    });
  });

  app.listen(port, () => {
    // eslint-disable-next-line no-console
    console.log(`[Cube Events] SSE listening on :${port}${path}`);
  });
}
