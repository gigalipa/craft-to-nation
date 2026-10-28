import React from "react";
import { staticFile, Audio, useCurrentFrame, useVideoConfig } from "remotion";
import { Video } from "@remotion/media";

export interface CaptionSegment {
  start: number; // in seconds relative to clip start
  end: number;   // in seconds relative to clip start
  text: string;
}

interface VerticalShortProps {
  startSec: number;
  durationSec: number;
  musicTrack: string;
  segments: CaptionSegment[];
}

export const VerticalShort: React.FC<VerticalShortProps> = ({
  startSec,
  durationSec,
  musicTrack,
  segments,
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
          src={staticFile("live_w2.mp4")}
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
          src={staticFile("live_w2.mp4")}
          trimBefore={trimBefore}
          durationInFrames={durationInFrames}
          objectFit="contain"
          style={{
            width: 1080,
            height: "auto",
            display: "block",
          }}
        />
      </div>

      {/* Subtitles: Dynamic HUD styling with safe zone at bottom: 350px */}
      {activeSegment && (
        <div
          style={{
            position: "absolute",
            bottom: 350,
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
              backgroundColor: "rgba(10, 32, 10, 0.85)",
              border: "3px solid #F6C424",
              borderRadius: "18px",
              padding: "16px 32px",
              boxShadow: "0 8px 30px rgba(0, 0, 0, 0.85), 0 0 15px rgba(246, 196, 36, 0.35)",
              maxWidth: 1000,
            }}
          >
            <span
              style={{
                fontFamily: "'Trebuchet MS', sans-serif",
                fontSize: 48,
                fontWeight: "900",
                color: "#F6C424",
                WebkitTextStroke: "1.5px #144214",
                textShadow: "2px 2px 6px rgba(0, 0, 0, 0.9)",
                lineHeight: 1.3,
                letterSpacing: "0.5px",
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
