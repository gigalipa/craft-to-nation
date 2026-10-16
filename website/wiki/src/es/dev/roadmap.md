# Hoja de Ruta (Roadmap) y Próximos Pasos

La evolución técnica de *Craft to Nation* sigue un plan de desarrollo iterativo sustentado en pruebas automatizadas y validación en vivo. A continuación se desglosa el estado de las fases del proyecto y los hitos inmediatos.

---

## 1. Resumen de Fases del Proyecto

```
[Fase 1: Génesis y Vóxeles] ───> COMPLETADO ✅
[Fase 2: Blueprints y Cámara Cenital] ───> COMPLETADO ✅
[Fase 3: Industrias, Fluidos y Moral v3.56] ───> COMPLETADO ✅ (28 escenas en verde)
[Fase 3.5: Cierre de Automatización y Cuotas] ───> EN CURSO 🟡
[Fase 4: Escuadrones RTS y Asedios] ───> PLANIFICADO ⏳
[Fase 5: Carretas, Redes Férreas y Puentes] ───> EN DISEÑO ⏳
[Fase 6: Multijugador y Soberanía Portátil] ───> HORIZONTE FUTURO 🚀
```

---

## 2. Hitos Completados Recientemente (Fases 1, 2 y 3)

### Fase 1: Motor Vóxel y Avatar en Primera Persona
- Mundo procedural infinito basado en chunks tridimensionales (`VoxelWorld.gd`).
- Avatar con físicas de movimiento en tierra y natación fluida con barra de oxígeno (`PlayerNatacionTest.tscn`).
- Linterna de minero y farol de mano (`L`) con cálculo de visibilidad para exploración subterránea profunda.

### Fase 2: Fundación Cívica y Validación Volumétrica
- Algoritmo de reconocimiento de habitaciones herméticas por inundación de volumen (`BlueprintValidator.gd`).
- Catálogo de blueprints guardados (hasta 5 diseños persistentes) con previsualización isométrica en miniatura.
- Cámara cenital con rotación orbital suave y alternancia instantánea mediante tecla de acceso rápido.
- Inmigración cívica vinculada a camas residenciales libres en la Zona A.

### Fase 3: Puestos Periféricos, Fluidos y Moral Dinámica (GDD v3.56)
- Edificios de recolección de bloques físicos reales: madereros, minas de subsuelo, caza y pesca sobre agua.
- Red de carreteras de tierra pisada con trazador cenital (<kbd>V</kbd>), rampas suaves y bono de velocidad del **+35%**.
- Cadenas de refinamiento: siderúrgicas (acero), aserraderos (tablas), carboneras y refinerías petroleras.
- Red aérea modular de canalizaciones y tuberías con galibo libre en `Y + 5` y dinámica de derrames viscosos.
- Sistema de Moral Dinámica [0–100], productividad continua por curva exponencial y 28 escenas de prueba al 100% en verde.

---

## 3. En Curso: Cierre de Fase 3 y Automatización Cívica

Actualmente el equipo se enfoca en afinar los aspectos de conveniencia y autonomía previa a la fase militar:

1. **Construcción Asistida de Vías por Colonos:** Delegación del tendido de carreteras a cuadrillas de obreros para evitar que el jugador deba construir cada bloque de vía manualmente.
2. **Bombas de Extracción Sumergibles:** Instalación de cabezales extractores automáticos en lagos y acuíferos profundos sin requerir operarios continuos.
3. **Control de Cuotas y Reservas de Materia Prima:** Panel de configuración en aserraderos y fundiciones que impide consumir madera o hierro por debajo de un umbral de seguridad para construcciones.
4. **Consumo Universal de Energía de Era 3:** Activación de la red eléctrica en edificios civiles y residencias a medida que se implemente la automatización urbana.

---

## 4. Hitos Futuros (Fases 4 a 6)

### Fase 4: Modo Estratégico RTS y Asedios (PoC 7)
- **Cámara Dual de Combate:** Comando táctico de escuadras militares desde la vista cenital con órdenes de formación, avance y ataque concentrado.
- **Campamentos Enemigos Procedurales:** Fortalezas controladas por IA con patrullas de asalto que amenazan las líneas de suministro de la colonia.
- **Estructuras Defensivas:** Murallas de sillería, fosos, torres de balistas y portones levadizos.

### Fase 5: Transporte Masivo, Carretas y Puentes (PoC 8–10)
- **Vehículos Terrestres:** Carretas tiradas por bueyes y camiones a vapor para acarreos masivos de 500+ unidades.
- **Sistema de Puentes Modulares:** Viaductos y puentes colgantes sobre masas fluviales y cañones.
- **Redes Ferroviarias:** Vías férreas de alta velocidad con locomotoras para abastecer refinerías distantes.

### Fase 6: Soberanía Portátil y Multijugador Competitivo
- Despliegue de núcleos urbanos exportables en servidores multijugador procedurales.
- Sala de trofeos en el núcleo central que potencia permanentemente la moral de los colonos.
