import React from "react";
import { staticFile, Audio, useVideoConfig } from "remotion";
import { Video } from "@remotion/media";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { LowerThird } from "./LowerThird";

export const QA_RECAP_CUTS = [
  { startSec: 8.0, durationSec: 50.0, title: "1. Guion de QA y Balance de Recursos" },
  { startSec: 435.0, durationSec: 52.0, title: "2. Física de Agua y Contador de Oxígeno" },
  { startSec: 2330.0, durationSec: 55.0, title: "3. Viviendas, Desahucios y Caza de Bugs" },
  { startSec: 4325.0, durationSec: 52.0, title: "4. Almacén Desplegable y Comida Perecedera" },
  { startSec: 5380.0, durationSec: 58.0, title: "5. Sitio Web Oficial y Calculadora en la Wiki" },
];

export const QASessionRecap: React.FC = () => {
  const { fps } = useVideoConfig();
  const transitionDuration = Math.round(0.75 * fps);

  return (
    <div
      style={{
        flex: 1,
        backgroundColor: "#000",
        width: "100%",
        height: "100%",
        position: "relative",
      }}
    >
      <TransitionSeries>
        {QA_RECAP_CUTS.map((cut, index) => {
          const durationInFrames = Math.round(cut.durationSec * fps);
          const trimBefore = Math.round(cut.startSec * fps);

          return (
            <React.Fragment key={index}>
              <TransitionSeries.Sequence durationInFrames={durationInFrames}>
                <Video
                  src={staticFile("QA_session_1_28-10-26.mp4")}
                  trimBefore={trimBefore}
                  durationInFrames={durationInFrames}
                  volume={1.8}
                  objectFit="contain"
                  style={{ width: "100%", height: "100%" }}
                />
                <LowerThird title={cut.title} />
              </TransitionSeries.Sequence>
              {index < QA_RECAP_CUTS.length - 1 && (
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
