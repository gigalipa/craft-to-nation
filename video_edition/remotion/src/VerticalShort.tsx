import React from "react";
import { staticFile, Audio, useCurrentFrame, useVideoConfig } from "remotion";
import { Video } from "@remotion/media";

export interface CaptionSegment {
  start: number; // in seconds relative to clip start
  end: number;   // in seconds relative to clip start
  text: string;
}

export interface VerticalShortProps {
  startSec?: number;
  durationSec?: number;
  musicTrack?: string;
  segments?: CaptionSegment[];
  srcVideo?: string;
  volumeBoost?: number;
}

export const VerticalShort: React.FC<VerticalShortProps> = ({
  startSec = 0,
  durationSec = 0,
  musicTrack = "",
  segments = [],
  srcVideo = "live_w2.mp4",
  volumeBoost = 1.8,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const currentSec = frame / fps;
  const durationInFrames = Math.round(durationSec * fps);
  const trimBefore = Math.round(startSec * fps);

  // Active subtitle segment
  const activeSegment = segments.find(
    (s) => currentSec >= s.start && currentSec < s.end
  );

  return (
    <div
      style={{
        width: 1080,
        height: 1920,
        backgroundColor: "#000",
        position: "relative",
        overflow: "hidden",
      }}
    >
      {/* Background layer: Scaled and blurred gameplay */}
      <div
        style={{
          position: "absolute",
          top: 0,
          left: 0,
          width: 1080,
          height: 1920,
          overflow: "hidden",
          transform: "scale(1.2)",
          filter: "blur(25px) brightness(0.75)",
        }}
      >
        <Video
          src={staticFile(srcVideo)}
          trimBefore={trimBefore}
          durationInFrames={durationInFrames}
          volume={0}
          objectFit="cover"
          style={{
            width: "100%",
            height: "100%",
          }}
        />
      </div>

      {/* Foreground layer: Original 16:9 gameplay centered */}
      <div
        style={{
          position: "absolute",
          top: "50%",
          left: 0,
          width: 1080,
          transform: "translateY(-50%)",
          boxShadow: "0 10px 40px rgba(0,0,0,0.8)",
          zIndex: 10,
        }}
      >
        <Video
          src={staticFile(srcVideo)}
          trimBefore={trimBefore}
          durationInFrames={durationInFrames}
          volume={volumeBoost}
          objectFit="contain"
          style={{
            width: 1080,
            height: "auto",
            display: "block",
          }}
        />
      </div>

      {/* Subtitles: High-contrast, fatigue-free modern captions */}
      {activeSegment && (
        <div
          style={{
            position: "absolute",
            bottom: 340,
            left: 40,
            right: 40,
            display: "flex",
            justifyContent: "center",
            alignItems: "center",
            textAlign: "center",
            zIndex: 30,
          }}
        >
          <div
            style={{
              backgroundColor: "rgba(0, 0, 0, 0.84)",
              borderRadius: "20px",
              padding: "18px 36px",
              boxShadow: "0 12px 40px rgba(0, 0, 0, 0.9), 0 0 0 1.5px rgba(255, 255, 255, 0.14)",
              maxWidth: 980,
            }}
          >
            <span
              style={{
                fontFamily: "system-ui, -apple-system, 'Trebuchet MS', 'Segoe UI', Roboto, sans-serif",
                fontSize: 58,
                fontWeight: "900",
                color: "#FFFFFF",
                textShadow: "0 3px 12px rgba(0, 0, 0, 0.95)",
                lineHeight: 1.28,
                letterSpacing: "-0.2px",
                display: "inline-block",
              }}
            >
              {activeSegment.text}
            </span>
          </div>
        </div>
      )}

      {/* Background Loop Music with Sidechain Ducking */}
      <Audio
        src={staticFile(musicTrack)}
        volume={0.03}
        loop
      />
    </div>
  );
};
