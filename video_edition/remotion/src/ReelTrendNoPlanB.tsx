import React from "react";
import { staticFile, useVideoConfig, Img } from "remotion";
import { Video } from "@remotion/media";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";

export const ReelTrendNoPlanB: React.FC = () => {
  const { fps } = useVideoConfig();
  const transitionDuration = Math.round(0.5 * fps); // 15 frames a 30 fps

  // Escena 1: Programando en el editor de código (16.5s a 20.25s)
  const codeDurationFrames = Math.round(3.75 * fps);
  const codeTrimBefore = Math.round(16.5 * fps);

  // Escena 2: Jugando y testeando el juego en 3D (204.5s a 208.25s)
  const gameDurationFrames = Math.round(3.75 * fps);
  const gameTrimBefore = Math.round(204.5 * fps);

  return (
    <div
      style={{
        flex: 1,
        backgroundColor: "#000",
        width: "100%",
        height: "100%",
        position: "relative",
        overflow: "hidden",
      }}
    >
      {/* Video B-roll multi-corte con transición suave */}
      <TransitionSeries>
        {/* Clip 1: Código / Godot Editor */}
        <TransitionSeries.Sequence durationInFrames={codeDurationFrames}>
          <Video
            src={staticFile("reel_01_raw.mp4")}
            trimBefore={codeTrimBefore}
            durationInFrames={codeDurationFrames}
            muted
            objectFit="cover"
            style={{ width: "100%", height: "100%" }}
          />
        </TransitionSeries.Sequence>

        {/* Transición suave entre código y juego */}
        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: transitionDuration })}
        />

        {/* Clip 2: Juego corriendo / Test de Gameplay */}
        <TransitionSeries.Sequence durationInFrames={gameDurationFrames}>
          <Video
            src={staticFile("reel_01_raw.mp4")}
            trimBefore={gameTrimBefore}
            durationInFrames={gameDurationFrames}
            muted
            objectFit="cover"
            style={{ width: "100%", height: "100%" }}
          />
        </TransitionSeries.Sequence>
      </TransitionSeries>

      {/* Logo oficial de Craft to Nation en la esquina superior izquierda */}
      <div
        style={{
          position: "absolute",
          top: 75,
          left: 65,
          zIndex: 20,
          pointerEvents: "none",
        }}
      >
        <Img
          src={staticFile("craft-to-nation-logo.png")}
          style={{
            width: 140,
            height: "auto",
            filter: "drop-shadow(0px 6px 14px rgba(0, 0, 0, 0.75))",
          }}
        />
      </div>

      {/* Frase Viral en el tercio superior con verde oficial y borde dorado nítido */}
      <div
        style={{
          position: "absolute",
          top: 250,
          left: 0,
          right: 0,
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          padding: "0 60px",
          zIndex: 10,
          pointerEvents: "none",
        }}
      >
        <h1
          style={{
            fontFamily:
              "'Trebuchet MS', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
            fontSize: 58,
            fontWeight: 900,
            lineHeight: 1.25,
            color: "#1B6B2B",
            WebkitTextStroke: "4px #F6C424",
            paintOrder: "stroke fill",
            textAlign: "center",
            margin: 0,
            letterSpacing: "0.5px",
            filter:
              "drop-shadow(0px 4px 10px rgba(0, 0, 0, 0.95)) drop-shadow(0px 0px 4px rgba(0, 0, 0, 0.85))",
            maxWidth: 900,
          }}
        >
          No hay plan B, vamos a hacer que esto funcione
        </h1>
      </div>
    </div>
  );
};
