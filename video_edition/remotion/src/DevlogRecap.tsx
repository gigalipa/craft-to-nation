import React from "react";
import { staticFile, Audio, useVideoConfig } from "remotion";
import { Video } from "@remotion/media";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { LowerThird } from "./LowerThird";

export const RECAP_CUTS = [
  { startSec: 41.0, durationSec: 54.0, title: "1. Nuevo HUD Profesional y Sistema de Moral" },
  { startSec: 95.0, durationSec: 44.0, title: "2. Escalones Migratorios y Crecimiento Urbano" },
  { startSec: 139.0, durationSec: 41.0, title: "3. Fábrica de Bloques y Control de Reservas" },
  { startSec: 180.0, durationSec: 35.0, title: "4. Métricas de Población y Red Eléctrica" },
  { startSec: 740.0, durationSec: 40.0, title: "5. Iconografía y Flujos de Producción" },
];

export const DevlogRecap: React.FC = () => {
  const { fps } = useVideoConfig();
  const transitionDuration = Math.round(0.75 * fps);

  return (
    <div style={{ flex: 1, backgroundColor: "#000", width: "100%", height: "100%", position: "relative" }}>
      <TransitionSeries>
        {RECAP_CUTS.map((cut, index) => {
          const durationInFrames = Math.round(cut.durationSec * fps);
          const trimBefore = Math.round(cut.startSec * fps);

          return (
            <React.Fragment key={index}>
              <TransitionSeries.Sequence durationInFrames={durationInFrames}>
                <Video
                  src={staticFile("live_w2.mp4")}
                  trimBefore={trimBefore}
                  durationInFrames={durationInFrames}
                  objectFit="contain"
                  style={{ width: "100%", height: "100%" }}
                />
                <LowerThird title={cut.title} />
              </TransitionSeries.Sequence>
              {index < RECAP_CUTS.length - 1 && (
                <TransitionSeries.Transition
                  presentation={fade()}
                  timing={linearTiming({ durationInFrames: transitionDuration })}
                />
              )}
            </React.Fragment>
          );
        })}
      </TransitionSeries>
      <Audio
        src={staticFile("audio/Clockwork_logistics (loop).mp3")}
        volume={0.03}
        loop
      />
    </div>
  );
};
