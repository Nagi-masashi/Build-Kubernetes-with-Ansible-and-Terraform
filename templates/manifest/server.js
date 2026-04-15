import express from "express";
import cors from "cors";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import { generateContent } from "./claude.js";
import { validateRequest } from "./middleware.js";

const app = express();
const PORT = process.env.PORT || 3001;

app.use(helmet());
app.use(cors({ origin: process.env.FRONTEND_URL || "http://localhost:3000" }));
app.use(express.json({ limit: "10kb" }));

// Rate limiting: 20 requests per minute per IP
const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  message: { error: "Too many requests. Please slow down." },
});
app.use("/api/", limiter);

// Health check (used by K8s liveness/readiness probes)
app.get("/health", (_req, res) => res.json({ status: "ok" }));

// Main generation endpoint
app.post("/api/generate", validateRequest, async (req, res) => {
  const { industry, docType, context, language } = req.body;

  try {
    // Stream response back to client
    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");

    await generateContent({ industry, docType, context, language }, (chunk) => {
      res.write(`data: ${JSON.stringify({ text: chunk })}\n\n`);
    });

    res.write("data: [DONE]\n\n");
    res.end();
  } catch (err) {
    console.error("Generation error:", err.message);
    res.status(500).json({ error: "Generation failed. Please try again." });
  }
});

app.listen(PORT, () => console.log(`Backend running on port ${PORT}`));
