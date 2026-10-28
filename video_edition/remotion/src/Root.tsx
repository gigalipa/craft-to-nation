import React from "react";
import { Composition } from "remotion";
import { DevlogRecap } from "./DevlogRecap";
import { VerticalShort } from "./VerticalShort";
import { SHORT_01_SEGMENTS, SHORT_02_SEGMENTS, SHORT_03_SEGMENTS } from "./data";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      {/* 1. Master Devlog Recap (16:9) */}
      <Composition
        id="live-w2-recap"
        component={DevlogRecap}
        durationInFrames={6330} // ~211 segundos a 30 fps
        fps={30}
        width={1920}
        height={1080}
      />

      {/* 2. Short #1: Fábrica de Bloques y Control de Reservas (9:16) */}
      <Composition
        id="live-w2-short-01"
        component={VerticalShort}
        durationInFrames={1230} // 41 segundos a 30 fps
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{
          startSec: 139.0,
          durationSec: 41.0,
          musicTrack: "audio/Clockwork_logistics (loop).mp3",
          segments: SHORT_01_SEGMENTS,
        }}
      />

      {/* 3. Short #2: Moral de Colonos y Escalones Migratorios (9:16) */}
      <Composition
        id="live-w2-short-02"
        component={VerticalShort}
        durationInFrames={1320} // 44 segundos a 30 fps
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{
          startSec: 95.0,
          durationSec: 44.0,
          musicTrack: "audio/Hard_stop (loop).mp3",
          segments: SHORT_02_SEGMENTS,
        }}
      />

      {/* 4. Short #3: HUD Profesional e Iconografía (9:16) */}
      <Composition
        id="live-w2-short-03"
        component={VerticalShort}
        durationInFrames={1200} // 40 segundos a 30 fps
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{
          startSec: 740.0,
          durationSec: 40.0,
          musicTrack: "audio/Cozy_colony (loop).mp3",
          segments: SHORT_03_SEGMENTS,
        }}
      />
    </>
  );
};
