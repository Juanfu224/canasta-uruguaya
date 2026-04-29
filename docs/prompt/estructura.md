# Los mejores trucos para mejorar tus prompts en Claude, dos tipos de estructura explicados por el propio equipo de Claude

**Autor:** Yúbal Fernández  
**Medio:** Xataka Basics  
**URL original:** https://www.xataka.com/basics/mejores-trucos-para-mejorar-tus-prompts-claude-dos-tipos-estructura-explicados-propio-equipo-claude

Vamos a decirte **dos estructuras para crear mejores prompts** en Claude, explicadas por el propio equipo de Anthropic, creadores de esta inteligencia artificial. Son estructuras muy precisas para esta IA en concreto, aunque también funcionarán bien en otras alternativas como ChatGPT, Gemini o Copilot entre otros. Esto es algo más avanzado que cuando te enseñamos cómo mejorar las respuestas de Claude de forma sencilla.

Se trata de una lección de buenas prácticas de prompting usando ingeniería de prompts, la práctica con la que mejorarlos los comandos que le das a las aplicaciones LLM. Vamos, que son trucos para aprender a comunicarte con una IA de manera más efectiva y a moldear sus respuestas para que sean mejores, más fiables, y más ceñidas a la tarea que quieres que realice.

Vamos a ofrecerte dos estructuras de prompts. La primera es **una estructura sencilla de cinco pasos**. Es perfecta para tareas relativamente sencillas o un poco avanzadas, y te la vamos a explicar en profundidad. Luego hay una estructura para tareas mucho más sofisticadas que tiene diez pasos, y en este caso te la vamos a resumir.

## Estructura en cinco pasos de un buen prompt

La mejor manera de comunicarte con la inteligencia artificial y con Claude en particular es saber **la mejor estructura para un buen prompt**. Estas estructuras están configuradas para asegurarte de darle toda la información necesaria para que la IA entienda correctamente lo que le estás pidiendo que haga.

**Esta es la mejor estructura para un prompt** según Anthropic:

1. Una o dos frases para establecer el rol y la descripción de la tarea que quieres que haga.
2. Añade contenido dinámico para contextualizar.
3. Instrucciones detalladas de la tarea.
4. Ejemplos de lo que quieres que haga (opcional).
5. Repetir las instrucciones críticas (sobre todo cuando escribes un prompt muy largo).

### 1. Describe el rol y la tarea a realizar

Como puedes ver, en primer lugar debes dedicarle un tiempo a establecer el rol de la IA, decir qué papel debe desempeñar. Por ejemplo, decirle que es un profesor de secundaria, o una IA especializada en revisar formularios de notificación de accidentes.

Junto al rol de la IA, también se recomienda **describir la tarea que debe realizar**. Vamos, que aquí es donde tienes que decirle lo que quieres que haga interpretando el rol que le has indicado. Estos dos elementos deberían ser el principio de un buen prompt.

### 2. Añade contenido dinámico para contextualizar

Después de describir la tarea, es útil proporcionar contenido para contextualizar mejor su tarea o **el contenido sobre el que quieres que trabaje**. Por ejemplo, si quieres que analice un texto, una fotografía, o incluso un enlace web, deberías añadirlo después de la descripción.

Este contenido también puede ser otro elemento que has obtenido de una aplicación, o incluso de una IA, ya sea una captura de pantalla o cualquier otra cosa. Lo principal es que **añadas lo que necesita la IA para hacer lo que le hayas pedido**. Puedes adjuntar varios archivos, pero luego tendrás que describir bien lo que quieres que haga con cada uno.

### 3. Instrucciones detalladas de la tarea

Al principio del prompt le has dicho de forma resumida lo que quieres que haga, y luego le has adjuntado el contenido sobre el que quieres que trabaje. Ahora, después de esta introducción tendrás que **detallar las instrucciones de la tarea** que quieres que realice.

Este fragmento de texto viene a ser el corazón de la tarea que estás programando. Tendrás que decirle lo que quieres que haga con precisión, igual que si se lo estuvieras diciendo a una persona para que esta lo entienda correctamente sin que tenga que preguntarte nada más. Si has añadido varias imágenes o distintos tipos de contenido para contextualizar, también tendrás que explicar qué quieres que haga con cada uno de los elementos.

### 4. Puedes darle ejemplos de lo que quieres que haga

Cuando no le das a la IA ningún ejemplo del resultado que quieres que te ofrezca es lo que se denomina un Zero-shot o "0 ejemplos". Con ello, confiarás ciegamente en que el modelo de inteligencia artificial sepa cómo hacer la tarea. Sin embargo, **cuando quieres obtener resultados muy concretos o con un formato específico**, entonces conviene que le expliques esto con ejemplos.

Puedes usar un solo ejemplo o varios ejemplos. Haciendo esto, el modelo verá los ejemplos de la tarea ya clasificada o resuelta, y usará esa información para generar las nuevas respuestas **manteniendo el mismo formato de respuesta** que tú le has indicado. Cuantos más ejemplos pongas, más preciso será el formato de la respuesta. Esto es algo opcional, pero en tareas que necesitan un tipo concreto de respuesta puede ser muy útil.

### 5. Repite las instrucciones críticas

Has empezado describiendo la tarea, y luego le has dado una descripción minuciosa de cada paso que debe dar. Pero si estás pidiendo que haga una tarea muy compleja con un prompt especialmente largo, conviene que **al final repitas las instrucciones más críticas** de la tarea que le has solicitado que haga.

**Esto es el equivalente a subrayar** los puntos más importantes y vitales de las instrucciones, algo que crees que es absolutamente vital que tenga siempre en cuenta y que no se le pase por alto.

## Estructura de prompt avanzada en 10 pasos

Si con la estructura de cinco pasos no tienes suficiente, los creadores de Claude también apuntan a una estructura de 10 pasos. Viene a ser como la primera que te hemos dicho, pero más fragmentada para **darle a IA todos y cada uno de los detalles** que va a necesitar.

Cada uno de estos pasos puede ser uno o varios párrafos en el prompt que vamos a componer. Esto no es necesario que lo hagas siempre, normalmente es suficiente con la anterior estructura, pero **para tareas especialmente complejas** puede ayudarte. Estos son los diez pasos resumidos para que los entiendas:

1. **Contexto de la tarea**: Tienes que darle el contexto de la tarea, el tipo de tarea que debe realizar. Por ejemplo, interpretar un documento de tráfico, analizar un texto, extraer información de una imagen, o lo que le vayas a pedir. Viene a ser como un encabezado.
2. **Contexto del tono**: Puedes decirle a Claude que sea objetivo, cercano, o que te hable de una manera determinada. También puedes especificar que solo responda cuando determine lo que responde es cierto, y que si tiene dudas te haga más preguntas. Con esto último evitarás forzar a la IA a que se invente cosas sin estar segura de ello.
3. **Datos adicionales, documentos e imágenes**: Tendrás que añadir todos los datos, imágenes y documentos sobre los que quieres que trabaje. Con esto, le estarás dando a Claude una importante información, información que no va a cambiar y sobre la que va a poder trabajar. Por ejemplo, si quieres que trabaje con formularios, primero puedes darle un formulario en blanco para que no pierda tiempo intentando adivinar cómo es y lo tenga en cuenta, lo que ayudará a que también lea mejor los otros formularios ya rellenados que le des. También puedes escribirle la estructura de los datos que va a recibir con etiquetas XML o incluso Markdown. Por ejemplo, puedes decirle que el formulario tendrá X columnas, cada una representando una cosa u otra, todo bien etiquetado para que se entienda mejor. Incluso puedes decirle que el formulario estará rellenado por humanos y que a veces habrá círculos indicando cosas, o texto que no esté perfectamente alineado en las casillas. Esto es solo para las tareas más avanzadas que realices en la consola de Anthropic.
4. **Descripción detallada de la tarea y normas**: Puedes hacer una lista de normas o tareas que debe realizar la IA con tu petición. Haz una especie de paso a paso para que Claude siga cada uno de ellos y así analice la información y realice la tarea de una manera informada. Esto es algo crítico en tareas que requieran un formato constante, una jerga específica o que siga determinados estándares empresariales. Muy a menudo la lista detallada de normas o pasos a realizar es más útil que darle ejemplos.
5. **Ejemplos**: También puedes añadir varios ejemplos del tipo de respuesta que quieres que te de la IA, para ayudar a establecer mejor el formato de respuesta deseado.
6. **Historial de conversación**: Si vas a hacer que Claude genere respuestas como si lo hicieras tú, o que realice tareas trabajando en tu nombre, conviene que le des ejemplos de cómo te expresas en conversaciones reales, y así ayudar a que la IA lo haga de forma similar. Este paso es opcional, y útil cuando vayas a realizar automatizaciones con Claude.
7. **Descripción inmediata de la tarea o petición**: Después de haber terminado con todos los puntos que le dan forma al contexto de tu petición, conviene recordarle a la IA los aspectos más críticos de tarea, subrayar las órdenes más importantes y la tarea concreta que debe realizar. Para evitar alucinaciones puedes añadir aquí órdenes como que responda solo si tiene confianza en la respuesta para evitar que se invente cosas, que piense antes de responder, que encuentre citas relevantes en documentos importantes, o que diga "No lo sé" cuando haya algo que no sabe.
8. **Pensamiento paso a paso**: Puedes darle a Claude indicaciones de cómo procesar la tarea paso a paso. Por ejemplo, imagínate que subes dos elementos, un documento y una imagen, y que si no lees el documento no entenderás la imagen. Entonces, dile que primero lea el documento y para qué quieres que lo haga, y luego que tenga en cuenta determinadas cosas para analizar la imagen de la manera que quieras. Viene a ser como darle las instrucciones paso a paso de lo que haga, y puedes añadir tantos pasos como necesites para que se ciña a ese orden.
9. **Formato de salida**: Después de darle el contexto y explicarle cómo quieres que realice su tarea, ahora toca empezar a darle formato a la respuesta que quieres que te de. Podrás decirle cómo quieres que sea la estructura de la respuesta de una manera tan detallada como quieras.
10. **Respuesta rellenada (si la hay)**: Y si estás buscando que la respuesta tenga de un formato concreto del que tengas ejemplo, puedes terminar dándole este contexto, ejemplos de la respuesta ya realizada para que se ciña a ese formato concreto evitando interpretaciones libres de las instrucciones que le has dado antes.