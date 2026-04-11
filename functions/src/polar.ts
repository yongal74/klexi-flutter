import { Polar } from "@polar-sh/sdk";

import type { Express, Request, Response } from "express";
import express from "express";

let polarClient: Polar | null = null;

function getPolarClient(): Polar {
  if (!polarClient) {
    const accessToken = process.env.POLAR_ACCESS_TOKEN;
    if (!accessToken) {
      throw new Error("POLAR_ACCESS_TOKEN is not configured");
    }
    polarClient = new Polar({
      accessToken,
      server: process.env.POLAR_ENV === "production" ? "production" : "sandbox",
    });
  }
  return polarClient;
}

export function setupPolarRoutes(app: Express) {
  app.post("/api/polar/checkout", async (req: Request, res: Response) => {
    try {
      const polar = getPolarClient();
      const { productId, customerEmail, successUrl, metadata } = req.body;

      if (!productId) {
        return res.status(400).json({ error: "productId is required" });
      }

      const checkout = await polar.checkouts.create({
        products: [productId],
        customerEmail: customerEmail || undefined,
        successUrl: successUrl || undefined,
        metadata: metadata || undefined,
      });

      return res.json({
        checkoutId: checkout.id,
        checkoutUrl: checkout.url,
      });
    } catch (error: any) {
      console.error("Polar checkout error:", error?.message || error);
      return res.status(500).json({ error: "Failed to create checkout session" });
    }
  });

  app.get("/api/polar/products", async (_req: Request, res: Response) => {
    try {
      const polar = getPolarClient();
      const result = await polar.products.list({ limit: 100 });
      const items: any[] = [];
      for await (const page of result) {
        items.push(...(page.result?.items || []));
      }
      return res.json({ products: items });
    } catch (error: any) {
      console.error("Polar products error:", JSON.stringify({ message: error?.message, statusCode: error?.statusCode, body: error?.body }));
      return res.status(500).json({ error: "Failed to fetch products", detail: error?.message });
    }
  });

  app.get("/api/polar/subscription/:id", async (req: Request, res: Response) => {
    try {
      const polar = getPolarClient();
      const subId = req.params.id as string;
      const subscription = await polar.subscriptions.get({ id: subId });
      return res.json({ subscription });
    } catch (error: any) {
      console.error("Polar subscription error:", error?.message || error);
      return res.status(500).json({ error: "Failed to fetch subscription" });
    }
  });

  app.post("/api/polar/subscription/:id/cancel", async (req: Request, res: Response) => {
    try {
      const polar = getPolarClient();
      const cancelId = req.params.id as string;
      const updated = await polar.subscriptions.update({
        id: cancelId,
        subscriptionUpdate: { cancelAtPeriodEnd: true },
      });
      return res.json({ subscription: updated });
    } catch (error: any) {
      console.error("Polar cancel error:", error?.message || error);
      return res.status(500).json({ error: "Failed to cancel subscription" });
    }
  });

  // ── 이메일로 구독 상태 검증 (Flutter 앱이 결제 완료 후 호출) ────────────────
  app.get("/api/polar/verify", async (req: Request, res: Response) => {
    try {
      const email = req.query.email as string;
      if (!email) {
        return res.status(400).json({ error: "email is required" });
      }

      const polar = getPolarClient();

      // 1단계: 이메일로 고객 조회
      const customerResult = await polar.customers.list({ email, limit: 1 });
      let customerId: string | null = null;
      for await (const page of customerResult) {
        const items = page.result?.items || [];
        if (items.length > 0) { customerId = (items[0] as any).id; break; }
      }

      if (!customerId) {
        return res.json({ active: false, subscriptionId: null, status: null });
      }

      // 2단계: 고객 ID로 구독 조회
      const result = await polar.subscriptions.list({ customerId, active: true, limit: 5 });
      let activeSubscription: any = null;
      for await (const page of result) {
        const items = page.result?.items || [];
        activeSubscription = items.find(
          (sub: any) => sub.status === "active" || sub.status === "trialing"
        );
        if (activeSubscription) break;
      }

      return res.json({
        active: !!activeSubscription,
        subscriptionId: activeSubscription?.id || null,
        status: activeSubscription?.status || null,
      });
    } catch (error: any) {
      console.error("Polar verify error:", error?.message || error);
      return res.status(500).json({ error: "Failed to verify subscription" });
    }
  });

  app.post(
    "/api/polar/webhook",
    express.raw({ type: "application/json" }),
    async (req: Request, res: Response) => {
      const webhookSecret = process.env.POLAR_WEBHOOK_SECRET;
      if (!webhookSecret) {
        console.error("POLAR_WEBHOOK_SECRET not configured");
        return res.sendStatus(500);
      }

      try {
        const body = typeof req.body === "string" ? req.body : JSON.stringify(req.body);
        const event = JSON.parse(body);
        console.log(`Polar webhook: ${event.type}`);
        return res.sendStatus(200);
      } catch (error) {
        console.error("Webhook processing error:", error);
        return res.sendStatus(500);
      }
    }
  );
}
