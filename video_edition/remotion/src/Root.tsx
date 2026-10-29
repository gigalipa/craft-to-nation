import React from "react";
import { Composition } from "remotion";
import { DevlogRecap } from "./DevlogRecap";
import { QASessionRecap } from "./QASessionRecap";
import { VerticalShort } from "./VerticalShort";
import { ReelTrendNoPlanB } from "./ReelTrendNoPlanB";
import { SHORT_01_SEGMENTS, SHORT_02_SEGMENTS, SHORT_03_SEGMENTS } from "./data";
import qaData from "./qa_shorts_data.json";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      {/* 0. Reel Viral Trend: "No hay plan B" (9:16 | 7s) */}
      <Composition
        id="reel-trend-no-plan-b"
        component={ReelTrendNoPlanB}
        durationInFrames={211}
        fps={30}
        width={1080}
        height={1920}
      />

      {/* 1. Master Devlog Recap Live W2 (16:9) */}
      <Composition
        id="live-w2-recap"
        component={DevlogRecap}
        durationInFrames={6330}
        fps={30}
        width={1920}
        height={1080}
      />

      {/* 2. QA Session 1 Recap Master (16:9 | 264s / 4:24 min) */}
      <Composition
        id="qa-session-01-recap"
        component={QASessionRecap}
        durationInFrames={7920}
        fps={30}
        width={1920}
        height={1080}
      />

      {/* 3. QA Short #1: Física de Agua, Corrientes y Oxígeno (9:16 | 47s) */}
      <Composition
        id="qa-session-01-short-01"
        component={VerticalShort}
        durationInFrames={1410} // 47s a 30 fps
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{
          startSec: qaData.qa_short_01.startSec,
          durationSec: qaData.qa_short_01.durationSec,
          musicTrack: "audio/Glitch_drift (loop).mp3",
          segments: qaData.qa_short_01.segments,
          srcVideo: "QA_session_1_28-10-26.mp4",
          volumeBoost: 1.8,
        }}
      />

      {/* 4. QA Short #2: Caza de Bugs en Vivo - Desahucio y Empleo (9:16 | 43s) */}
      <Composition
        id="qa-session-01-short-02"
        component={VerticalShort}
        durationInFrames={1290} // 43s a 30 fps
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{
          startSec: qaData.qa_short_02.startSec,
          durationSec: qaData.qa_short_02.durationSec,
          musicTrack: "audio/Hard_stop_2 (loop).mp3",
          segments: qaData.qa_short_02.segments,
          srcVideo: "QA_session_1_28-10-26.mp4",
          volumeBoost: 1.8,
        }}
      />

      {/* 5. QA Short #3: Almacén Desplegable y Comida Perecedera (9:16 | 44s) */}
      <Composition
        id="qa-session-01-short-03"
        component={VerticalShort}
        durationInFrames={1320} // 44s a 30 fps
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{
          startSec: qaData.qa_short_03.startSec,
          durationSec: qaData.qa_short_03.durationSec,
          musicTrack: "audio/Clockwork_logistics_2 (loop).mp3",
          segments: qaData.qa_short_03.segments,
          srcVideo: "QA_session_1_28-10-26.mp4",
          volumeBoost: 1.8,
        }}
      />

      {/* 6. QA Short #4: Tour por la Wiki y Calculadora de Supervivencia (9:16 | 47s) */}
      <Composition
        id="qa-session-01-short-04"
        component={VerticalShort}
        durationInFrames={1410} // 47s a 30 fps
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{
          startSec: qaData.qa_short_04.startSec,
          durationSec: qaData.qa_short_04.durationSec,
          musicTrack: "audio/Cozy_colony (loop).mp3",
          segments: qaData.qa_short_04.segments,
          srcVideo: "QA_session_1_28-10-26.mp4",
          volumeBoost: 1.8,
        }}
      />
    </>
  );
};
