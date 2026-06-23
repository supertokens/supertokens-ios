import cors from "cors";
import express from "express";
import SuperTokens from "supertokens-node";
import { middleware, errorHandler } from "supertokens-node/framework/express";
import EmailPassword from "supertokens-node/recipe/emailpassword";
import Session from "supertokens-node/recipe/session";
import { verifySession } from "supertokens-node/recipe/session/framework/express";
import type { SessionContainerInterface } from "supertokens-node/recipe/session/types";

const port = Number(process.env.PORT ?? 3001);
const apiDomain = process.env.API_DOMAIN ?? `http://localhost:${port}`;
const websiteDomain = process.env.WEBSITE_DOMAIN ?? apiDomain;
const apiBasePath = "/auth";

type RequestWithSession = express.Request & {
  session?: SessionContainerInterface;
};

const refreshOnceAttemptsBySession = new Map<string, number>();

SuperTokens.init({
  framework: "express",
  supertokens: {
    connectionURI: "https://try.supertokens.com",
  },
  appInfo: {
    appName: "SuperTokens iOS Email Password Example",
    apiDomain,
    websiteDomain,
    apiBasePath,
    websiteBasePath: "/auth",
  },
  recipeList: [
    EmailPassword.init(),
    Session.init(),
  ],
});

const app = express();

app.use((req, res, next) => {
  const startedAt = Date.now();

  res.on("finish", () => {
    const durationMs = Date.now() - startedAt;
    console.log(`${req.method} ${req.originalUrl} -> ${res.statusCode} (${durationMs}ms)`);
  });

  next();
});

app.use(express.json());
app.use(
  cors({
    origin: websiteDomain,
    allowedHeaders: ["content-type", ...SuperTokens.getAllCORSHeaders()],
    credentials: true,
  })
);
app.use(middleware());

app.get("/public/config", (_req, res) => {
  res.json({
    apiDomain,
    apiBasePath,
    core: "https://try.supertokens.com",
    recipe: "email-password",
  });
});

app.get("/session", verifySession(), async (req: RequestWithSession, res) => {
  const session = req.session!;
  res.json({
    status: "OK",
    userId: session.getUserId(),
    sessionHandle: session.getHandle(),
    accessTokenPayload: session.getAccessTokenPayload(),
  });
});

app.post("/session/custom-claim", verifySession(), async (req: RequestWithSession, res) => {
  const value = String(req.body.value ?? "set-from-ios-example");
  await req.session!.mergeIntoAccessTokenPayload({ exampleClaim: value });
  res.json({ status: "OK", exampleClaim: value });
});

app.post("/debug/refresh-once/reset", verifySession(), async (req: RequestWithSession, res) => {
  const session = req.session!;
  refreshOnceAttemptsBySession.set(session.getHandle(), 0);
  res.json({ status: "OK" });
});

app.get("/debug/refresh-once", verifySession(), async (req: RequestWithSession, res) => {
  const session = req.session!;
  const sessionHandle = session.getHandle();
  const attempt = (refreshOnceAttemptsBySession.get(sessionHandle) ?? 0) + 1;
  refreshOnceAttemptsBySession.set(sessionHandle, attempt);

  if (attempt === 1) {
    res.status(401).json({
      status: "FORCED_401",
      message: "First request intentionally returns 401. The iOS SDK should refresh and retry.",
      attempt,
    });
    return;
  }

  res.json({
    status: "OK",
    message: "Second request succeeded after SDK refresh/retry.",
    attempt,
    userId: session.getUserId(),
    sessionHandle,
    accessTokenPayload: session.getAccessTokenPayload(),
  });
});

app.use(errorHandler());

app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  res.status(500).json({ status: "ERROR", message: err instanceof Error ? err.message : "Unknown error" });
});

app.listen(port, () => {
  console.log(`Email password backend listening on ${apiDomain}`);
  console.log("SuperTokens Core: https://try.supertokens.com");
});
