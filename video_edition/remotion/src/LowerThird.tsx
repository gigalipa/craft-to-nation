import React from "react";
import { interpolate, useCurrentFrame, useVideoConfig } from "remotion";

interface LowerThirdProps {
  title: string;
}

export const LowerThird: React.FC<LowerThirdProps> = ({ title }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Entrance from 0.5s to 1.0s, stays until 3.5s, exit by 4.0s
  const opacity = interpolate(
    frame,
    [0.5 * fps, 1.0 * fps, 3.5 * fps, 4.0 * fps],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );

  const translateY = interpolate(
    frame,
    [0.5 * fps, 1.0 * fps, 3.5 * fps, 4.0 * fps],
    [20, 0, 0, 10],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );

  if (opacity <= 0) return null;

  return (
    <div
      style={{
        position: "absolute",
        left: 80,
        bottom: 80,
        opacity,
        transform: `translateY(${translateY}px)`,
        backgroundColor: "rgba(20, 66, 20, 0.88)",
        border: "3px solid #F6C424",
        borderRadius: "10px",
        padding: "12px 28px",
        boxShadow: "0 8px 24px rgba(0, 0, 0, 0.6)",
        zIndex: 50,
      }}
    >
      <span
        style={{
          fontFamily: "'Trebuchet MS', sans-serif",
          fontSize: 36,
          fontWeight: "bold",
          color: "#F6C424",
          textShadow: "2px 2px 4px rgba(0, 0, 0, 0.9)",
          letterSpacing: "0.5px",
        }}
      >
        {title}
      </span>
    </div>
  );
};
