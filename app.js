const { useCallback, useEffect, useMemo, useRef, useState } = React;

const h = React.createElement;

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function round(value, digits = 0) {
  const factor = Math.pow(10, digits);
  return Math.round(value * factor) / factor;
}

function useMotion() {
  const [state, setState] = useState({
    supported: false,
    permission: "idle",
    x: 0,
    y: 0,
    z: 0,
    active: false,
    source: "idle",
  });
  const smoothing = useRef({ x: 0, y: 0, z: 0 });
  const raf = useRef(0);

  useEffect(() => {
    const supported = typeof window !== "undefined" && "DeviceMotionEvent" in window;
    setState((prev) => ({ ...prev, supported }));
  }, []);

  useEffect(() => {
    return () => {
      if (raf.current) cancelAnimationFrame(raf.current);
      window.removeEventListener("devicemotion", onMotion);
    };
  }, []);

  const onMotion = useCallback((event) => {
    const g = event.accelerationIncludingGravity || event.acceleration || { x: 0, y: 0, z: 0 };
    const rawX = clamp((g.x || 0) / 9.81, -1, 1);
    const rawY = clamp((g.y || 0) / 9.81, -1, 1);
    const rawZ = clamp((g.z || 0) / 9.81, -1, 1);
    const next = {
      x: smoothing.current.x * 0.82 + rawX * 0.18,
      y: smoothing.current.y * 0.82 + rawY * 0.18,
      z: smoothing.current.z * 0.82 + rawZ * 0.18,
    };
    smoothing.current = next;

    if (!raf.current) {
      raf.current = requestAnimationFrame(() => {
        raf.current = 0;
        setState((prev) => ({
          ...prev,
          x: smoothing.current.x,
          y: smoothing.current.y,
          z: smoothing.current.z,
          active: true,
          source: "sensor",
        }));
      });
    }
  }, []);

  async function enable() {
    if (!state.supported) {
      setState((prev) => ({ ...prev, permission: "unavailable" }));
      return;
    }

    const needsPermission = typeof DeviceMotionEvent !== "undefined" && typeof DeviceMotionEvent.requestPermission === "function";
    if (needsPermission) {
      try {
        const result = await DeviceMotionEvent.requestPermission();
        if (result !== "granted") {
          setState((prev) => ({ ...prev, permission: "denied" }));
          return;
        }
      } catch (error) {
        setState((prev) => ({ ...prev, permission: "denied" }));
        return;
      }
    }

    window.removeEventListener("devicemotion", onMotion);
    window.addEventListener("devicemotion", onMotion, { passive: true });
    setState((prev) => ({ ...prev, permission: "granted", source: "sensor" }));
  }

  return { ...state, enable };
}

function useHeartRate() {
  const [state, setState] = useState({
    bpm: null,
    threshold: 120,
    source: "idle",
  });

  useEffect(() => {
    function setHeartRate(next) {
      const bpm = Number(next);
      if (!Number.isFinite(bpm) || bpm <= 0) return;
      setState((prev) => ({ ...prev, bpm: Math.round(bpm), source: "bridge" }));
    }

    window.setGemHeartRate = setHeartRate;

    function onMessage(event) {
      const data = event.data;
      if (!data || typeof data !== "object") return;
      if (data.type === "heart-rate" || data.type === "gem-heart-rate") {
        setHeartRate(data.bpm);
      }
      if (data.type === "heart-rate-threshold") {
        const threshold = Number(data.threshold);
        if (Number.isFinite(threshold) && threshold > 0) {
          setState((prev) => ({ ...prev, threshold: Math.round(threshold) }));
        }
      }
    }

    window.addEventListener("message", onMessage);
    return () => {
      window.removeEventListener("message", onMessage);
      if (window.setGemHeartRate === setHeartRate) delete window.setGemHeartRate;
    };
  }, []);

  return {
    ...state,
    hot: state.bpm != null && state.bpm >= state.threshold,
  };
}

function App() {
  const motion = useMotion();
  const heart = useHeartRate();
  const [sensitivity, setSensitivity] = useState(0.75);
  const [fallback, setFallback] = useState({ x: 0, y: 0 });
  const [testAlert, setTestAlert] = useState(false);
  const alertTimer = useRef(0);
  const activeX = motion.active ? motion.x : fallback.x;
  const activeY = motion.active ? motion.y : fallback.y;
  const tiltX = clamp(activeX * sensitivity, -1, 1);
  const tiltY = clamp(activeY * sensitivity, -1, 1);
  const shimmer = clamp((Math.abs(tiltX) + Math.abs(tiltY)) * 0.45 + 0.12, 0.14, 1);
  const alertActive = testAlert;
  const glow = clamp((alertActive ? 0.95 : 0.32) + shimmer * (alertActive ? 1.05 : 0.88), 0.35, 1);
  const hue = alertActive ? 310 : Math.round(188 + tiltX * 14 - tiltY * 8);
  const lit = alertActive ? 60 : Math.round(62 + tiltY * 7);
  const sat = alertActive ? 98 : Math.round(84 - Math.abs(tiltX) * 8);

  const rootStyle = useMemo(
    () => ({
      "--tilt-x": tiltX.toFixed(3),
      "--tilt-y": tiltY.toFixed(3),
      "--shine": shimmer.toFixed(3),
      "--glow": glow.toFixed(3),
      "--hue": hue,
      "--lit": `${clamp(lit, 40, 67)}%`,
      "--sat": `${clamp(sat, 78, 100)}%`,
      "--sparkle": `${clamp(0.12 + shimmer * 0.4, 0.14, 0.5)}`,
      "--alert": alertActive ? "1" : "0",
      "--gem-core": alertActive ? "#ff82f0" : "#63dde0",
      "--gem-deep": alertActive ? "#7d2cf0" : "#2d86d8",
      "--gem-violet": alertActive ? "#ff77dd" : "#8f7cff",
      "--gem-highlight": "#ecffff",
    }),
    [tiltX, tiltY, shimmer, glow, hue, lit, sat, alertActive]
  );

  useEffect(() => {
    function onPointerMove(event) {
      const nx = ((event.clientX / window.innerWidth) - 0.5) * 2;
      const ny = ((event.clientY / window.innerHeight) - 0.5) * 2;
      setFallback({
        x: clamp(nx, -1, 1),
        y: clamp(ny, -1, 1),
      });
    }

    window.addEventListener("pointermove", onPointerMove, { passive: true });
    return () => {
      window.removeEventListener("pointermove", onPointerMove);
      if (alertTimer.current) clearTimeout(alertTimer.current);
    };
  }, []);

  return h(
    "main",
    { className: "app", style: rootStyle, "data-alert": alertActive ? "1" : "0" },
    h(
      "header",
      { className: "topbar" },
      h(
        "div",
        { className: "brand" },
        h("div", { className: "eyebrow" }, "ESEKAI MONOGATARI"),
        h("div", { className: "title" }, "幻の青を、角度で見つける")
      ),
      h(
        "div",
        { className: "badge" },
        h("span", { className: "badge-dot" }),
        h("span", null, alertActive ? "heart alert" : motion.supported ? "motion ready" : "sensor unavailable")
      )
    ),
    h(
      "section",
      { className: "alert-strip" },
      h(
        "div",
        { className: "alert-copy" },
        h("div", { className: "alert-label" }, "heart test"),
        h("div", { className: "alert-title" }, "心拍が高い時のボタン")
      ),
      h(
        "button",
        {
          className: `button secondary alert-button${testAlert ? " is-on" : ""}`,
          type: "button",
          onClick: () => {
            setTestAlert(true);
            if (alertTimer.current) clearTimeout(alertTimer.current);
            alertTimer.current = window.setTimeout(() => {
              setTestAlert(false);
              alertTimer.current = 0;
            }, 1800);
          },
        },
        h("span", { className: "icon", "aria-hidden": true }, "●"),
        h("span", null, "押して赤紫に光らせる")
      )
    ),
    h(
      "section",
      { className: "stage" },
      h(
        "div",
        { className: "gem-wrap" },
        h(
          "div",
          { className: "gem-shell" },
          h("div", { className: "shadow" }),
          h("div", { className: "gem" }, h("div", { className: "facet" }), h("div", { className: "facet two" }), h("div", { className: "facet three" }), h("div", { className: "glint" }))
        )
      ),
      h(
        "div",
        { className: "info" },
          h(
            "div",
            { className: "meters" },
          h(
            "div",
            { className: "meter" },
            h("span", { className: "meter-label" }, "tilt x"),
            h("span", { className: "meter-value" }, `${round(tiltX, 2).toFixed(2)}`),
            h("span", { className: "meter-sub" }, "left / right")
          ),
          h(
            "div",
            { className: "meter" },
            h("span", { className: "meter-label" }, "tilt y"),
            h("span", { className: "meter-value" }, `${round(tiltY, 2).toFixed(2)}`),
            h("span", { className: "meter-sub" }, "up / down")
          ),
          h(
            "div",
            { className: "meter" },
            h("span", { className: "meter-label" }, "heart"),
            h("span", { className: "meter-value" }, heart.bpm == null ? "--" : `${heart.bpm}`),
            h("span", { className: "meter-sub" }, `threshold ${heart.threshold} bpm`)
          ),
          h(
            "div",
            { className: "meter" },
            h("span", { className: "meter-label" }, "tone"),
            h("span", { className: "meter-value" }, alertActive ? "#ff82f0" : "#63dde0"),
            h("span", { className: "meter-sub" }, "current blue")
          )
        ),
        h(
          "div",
          { className: "controls" },
          h(
            "div",
            { className: "actions" },
            h(
              "button",
              { className: "button", onClick: motion.enable, type: "button" },
              h("span", { className: "icon", "aria-hidden": true }, "◉"),
              h("span", null, motion.permission === "granted" ? "センサーを再接続" : "センサーを有効にする")
            ),
            h(
              "button",
              {
                className: "button secondary",
                type: "button",
                onClick: () =>
                  setFallback({
                    x: 0,
                    y: 0,
                  }),
              },
              h("span", { className: "icon", "aria-hidden": true }, "↺"),
              h("span", null, "中央に戻す")
            )
          ),
          h(
            "label",
            { className: "slider" },
            h("div", { className: "slider-row" }, h("span", null, "心拍しきい値"), h("span", null, `${heart.threshold} bpm`)),
            h("input", {
              type: "range",
              min: "60",
              max: "180",
              step: "1",
              value: heart.threshold,
              onChange: (event) => window.postMessage({ type: "heart-rate-threshold", threshold: Number(event.target.value) }, "*"),
            })
          ),
          h(
            "label",
            { className: "slider" },
            h("div", { className: "slider-row" }, h("span", null, "感度"), h("span", null, `${Math.round(sensitivity * 100)}%`)),
            h("input", {
              type: "range",
              min: "0.25",
              max: "1.35",
              step: "0.01",
              value: sensitivity,
              onChange: (event) => setSensitivity(parseFloat(event.target.value)),
            })
          )
        )
      )
    ),
    h(
      "footer",
      { className: "footer" },
      h(
        "p",
        null,
        "端末を少し傾けると、青の表情が変わります。"
      ),
      h(
        "div",
        { className: "status" },
        alertActive
          ? "heart rate high"
          : heart.hot
            ? "heart rate high"
          : motion.permission === "denied"
            ? "権限が拒否されました"
            : motion.permission === "granted"
              ? "sensor live"
              : "drag to preview"
      )
    )
  );
}

const root = ReactDOM.createRoot(document.getElementById("root"));
root.render(h(App));
