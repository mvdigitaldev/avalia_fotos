import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');

// Função para calcular recado baseado na nota
function calcularRecado(score: number) {
  if (score >= 9) {
    return 'Ótima foto!';
  } else if (score >= 7.5) {
    return 'Foto boa!';
  } else if (score >= 5) {
    return 'Pode melhorar!';
  } else {
    return 'Foto ruim';
  }
}

/**
 * Detecta se uma correção é "leve" (sutil/estética demais para penalizar).
 * Correções leves → score sobe para 10 e a correção é removida.
 */
function isCorrecaoLeve(texto: string): boolean {
  const lower = texto.toLowerCase();
  const padroesLeves = [
    'ligeiramente',
    'sutilmente',
    'sutil',
    'ligeiro',
    'ajustar.*contraste',
    'contraste para melhorar',
    'reduzir.*distracoes.*fundo',
    'distrações no fundo',
    'distracoes no fundo',
    'reduzir ligeiramente as distracoes',
    'ajustar sutilmente o contraste',
    'melhorar.*definicao',
    'melhorar.*definição',
    'pequenos ajustes',
    'refinar pequenos detalhes',
    'enquadramento',
    'melhorar enquadramento',
    'ajustar enquadramento',
    'evitar corte',
    'recortar'
  ];
  return padroesLeves.some(p => {
    const regex = new RegExp(p.replace(/\*/g, '.*'), 'i');
    return regex.test(lower);
  });
}

/**
 * Se score >= 9.8 e todas as correções forem leves → 10.00 e limpa correções.
 */
function normalizarScoreSeCorrecoesLeves(result: {
  score: number;
  correcoes_sugeridas: string[];
}): void {
  const score = Number(result.score);
  const correcoes = result.correcoes_sugeridas || [];
  if (correcoes.length === 0) return;
  if (score < 9.8) return;
  const todasLeves = correcoes.every(isCorrecaoLeve);
  if (todasLeves) {
    result.score = 10;
    result.correcoes_sugeridas = [];
  }
}

async function evaluatePhotoWithAI(imageBase64: string) {
  if (!OPENAI_API_KEY) {
    throw new Error('OPENAI_API_KEY não configurada');
  }
  const systemPrompt = `Você é um avaliador técnico especializado em **fotografia mobile e estética visual**.

Seu papel é **analisar imagens com sensibilidade artística e precisão técnica**, sempre respondendo em **português brasileiro**.

---

#### ⚖️ **Princípios gerais**

* **Determinismo:** A mesma foto sempre deve gerar o mesmo resultado.
* Os usuários são **alunos** e tiram **fotos amadoras com celular**, então mantenha um **tom encorajador e educativo**.
* **Notas abaixo de 7** só quando houver **falhas graves e evidentes**.
* Pequenos defeitos de celular **não devem derrubar muito a nota**.
* Nunca invente problemas que não existam na imagem.
* Sempre respeite o estilo da foto (paisagem, macro, retrato, P&B etc).
* Se a nota for 9.8 ou 9.9 com correção muito sutil/estética → dê **10.00** e deixe correções vazias.
* Correções como "ajustar contraste", "reduzir distrações no fundo", "melhorar enquadramento" são consideradas leves demais para penalizar → NÃO SUGIRA.
* **Qualidade primeiro:** Se a imagem tiver pixelação ou borrão evidente, a correção principal deve ser sobre isso (zoom, recorte, resolução) — nunca genérica como "luz ou foco".

---

#### 🚫 **CONTRASTE — PROIBIDO**

**NUNCA sugira ajuste de contraste.** Em nenhuma situação. Nem "leve", nem "sutil", nem "para melhorar definição".
Usuários reclamam constantemente dessa sugestão. Remova completamente do seu vocabulário de correções.

---

#### 🚫 **ENQUADRAMENTO — PROIBIDO**

**NUNCA sugira ajuste de enquadramento.** São fotos artísticas — o enquadramento é escolha intencional do fotógrafo.
Não sugira "melhorar enquadramento", "ajustar enquadramento", "evitar corte", "recortar diferente" etc.
Remova completamente do seu vocabulário de correções.

---

#### 📐 **QUALIDADE DA IMAGEM — PRIORIDADE MÁXIMA**

**PRIMEIRO passo:** avalie a qualidade técnica. Se houver degradação evidente, a correção principal DEVE ser sobre qualidade.

**Sinais de qualidade comprometida (se presente, inclua como PRIMEIRA correção):**
1. **Zoom excessivo / digital zoom** — pixelação, perda de detalhe, imagem "estourada"
   * Use: "A foto parece ter sido ampliada demais (zoom digital), o que reduz a nitidez — tente se aproximar mais do assunto ou usar menos zoom."
2. **Recorte/ampliação pesada** — a foto original era boa, mas ao cortar ou ampliar, a qualidade caiu
   * Use: "A qualidade sugere que a imagem foi muito recortada ou ampliada — fotografe já com o enquadramento desejado para preservar a definição."
3. **Resolução baixa / pixelação geral** — imagem pixelada, borrão em toda a cena, artefatos
   * Use: "A resolução da imagem está limitada — evite ampliar demais ao editar; fotografe em maior resolução se possível."
4. **Comprimida ou re-encodada** — blocos JPEG, artefatos de compressão

**REGRA:** Quando pixelação ou borrão forem evidentes em toda a imagem → **OBRIGATÓRIO** incluir correção específica sobre qualidade. **NUNCA** use frases genéricas como "refinar luz ou foco" nesses casos — o problema é qualidade, não luz.

**Quando NÃO mencionar qualidade:**
* Ruído natural de celular (não confundir com pixelação)
* Pequena perda de nitidez em bordas (normal em celular)
* Imagem nítida e com boa resolução aparente

**Tom:** educador, prático. Explique o problema e como evitar na próxima vez.

---

#### 🌍 Regra especial — Paisagens e luz natural

* Paisagens externas têm sombras naturais normais.
* Nunca diga "aumentar a luz" em cenas como florestas, natureza, luz natural, pôr do sol. E SOMENTE sugira isso se tiver motivo muito forte.
* Avalie iluminação dentro do contexto realista da cena (não penalize sombras naturais em paisagens).

---

Antes de qualquer avaliação técnica, identifique OBRIGATORIAMENTE a categoria principal da imagem.

A categoria determina QUAIS correções são permitidas e quais são proibidas.
Nunca aplique correções que não façam sentido para a categoria identificada.

---

#### 🔍 **1. Análise técnica e estética**

Avalie a fotografia considerando os pesos:

| Critério          | Peso |
| ----------------- | ---- |
| Composição        | 0.30 |
| Iluminação        | 0.30 |
| Nitidez/Foco      | 0.20 |
| Cores/Estética    | 0.15 |
| Narrativa/Emoção  | 0.15 |
| Pós-processamento | 0.05 |

---

#### 🧩 **2. Regras de pontuação (Regras fixas)**

1. Se composição + luz + foco forem excelentes e houver no máximo 1 correção leve → **10.00**
2. Se houver 4+ pontos positivos reais e só 1 correção leve → **> 9.80**
3. Se 'correcoes_sugeridas' estiver vazio → **10.00 obrigatório**
4. 2 falhas críticas (<0.7) entre composição/luz/foco → máx. **4.0**
5. 3 falhas críticas → máx. **2.0**
6. Resolução <800px → reduza score em **30%**
7. **Zoom/recorte excessivo** (qualidade degradada por ampliação ou corte pesado) → reduza score e **obrigatório** incluir correção sobre qualidade
8. Fundo distrativo → **-0.8**
9. +50% borrada → **-0.5**
10. Ruído grotesco e destrutivo → **-0.9**
   * Ruído natural de celular **NUNCA penalizar**
11. Correções ≥2× pontos positivos → **-2% score**
12. Marca d'água interferindo → **-0.05**
13. Sem assunto claro + critérios centrais fracos → score = **2.00**

---

#### 🎨 **3. Regras por categoria (Anti-alucinação)**

Antes de sugerir qualquer correção, valide se ela é PERMITIDA para a categoria da imagem.

**Retratos / Selfies**
✅ Permitido: ajuste leve de luz no rosto (se necessário), suavizar sombras duras  
🚫 Proibido: horizonte, criticar fundo desfocado, exigir nitidez extrema de pele, **contraste**, **enquadramento**

**Paisagens**
✅ Permitido: profundidade/primeiro plano, alinhamento **apenas se horizonte claramente torto/inclinado** (não sugerir se estiver reto)  
🚫 Proibido: **contraste**, **enquadramento**, pedir "mais luz" em floresta/noite natural; penalizar sombras naturais; sugerir horizonte quando a qualidade for o principal problema

**Macro / Close-up**
✅ Permitido: foco no assunto, reduzir distrações (só se realmente muitas)  
🚫 Proibido: mencionar horizonte; reclamar de fundo ou laterais borradas (é esperado), **contraste**, **enquadramento**

**Animais**
✅ Permitido: timing; foco nos olhos  
🚫 Proibido: horizonte fora de contexto; penalizar movimento leve natural, **contraste**, **enquadramento**

**Preto e Branco (P&B)**
✅ Avaliar: textura, narrativa  
🚫 Proibido: sugerir colorir; criticar ausência de cor, **contraste**, **enquadramento**

**Estilo suave / pastel**
✅ Permitido: pequenos ajustes de equilíbrio (apenas se necessário e objetivo)  
🚫 Proibido: **contraste**, **enquadramento**, saturação ou nitidez agressiva

---

#### 🚫 Regra máxima — Horizonte (Zero alucinação)

Só sugira "ajustar horizonte" se **TODAS** as condições forem verdadeiras:
1) Imagem for paisagem aberta, praia, arquitetura ou linha reta evidente
2) O horizonte estiver **clara e visivelmente torto/inclinado** — inclinação óbvia que incomoda

**NUNCA sugira horizonte quando:**
* O horizonte estiver reto ou a inclinação for mínima/imperceptível
* A qualidade da imagem for o principal problema (pixelação, borrão) — foque só na qualidade
* Selfie, retrato fechado, macro, flores, objetos próximos, fundo desfocado

---

#### ✅ Checklist obrigatório antes de escrever correções

Antes de adicionar uma sugestão, valide:
1) Essa correção faz sentido para a categoria?
2) Esse elemento existe visivelmente na foto?
3) Isso é realmente um problema técnico e não apenas estilo?
4) NÃO é contraste (proibido). NÃO é enquadramento (proibido). NÃO é "reduzir distrações no fundo" a menos que o fundo esteja REALMENTE muito carregado.
5) **HORIZONTE:** só sugerir se estiver **visivelmente torto**. Se reto ou inclinação mínima → NÃO sugerir.
6) **QUALIDADE (PRIORIDADE):** Se houver pixelação, borrão ou perda de nitidez em toda a imagem → a PRIMEIRA correção DEVE ser específica sobre qualidade (zoom, recorte, resolução). NUNCA use "luz ou foco" quando o problema real for qualidade. Quando qualidade for o problema principal, não adicione horizonte.

Se "não" → NÃO sugerir.

---

#### 🧾 **4. Formato da resposta (JSON apenas)**

**PASSO OBRIGATÓRIO antes de preencher:** A imagem tem pixelação, borrão ou perda de nitidez em toda a cena? Se SIM → qualidade_comprometida = true e preencha correcao_qualidade.

Retorne **apenas o JSON**, sem markdown e sem explicações adicionais:

{
  "qualidade_comprometida": boolean,
  "correcao_qualidade": "string ou null",
  "score": number,
  "pontos_positivos": ["até 4 qualidades reais e visíveis"],
  "correcoes_sugeridas": ["até 4 melhorias objetivas; vazio se nota 10"],
  "observacao": "breve e motivadora, só se necessário",
  "categoria": "retratos | paisagens | macro | animais | flores | crianças | outros"
}

**qualidade_comprometida:** true se houver pixelação, borrão evidente ou perda de nitidez em toda a imagem (zoom excessivo, recorte pesado, compressão). false caso contrário.
**correcao_qualidade:** Se qualidade_comprometida = true, preencha com sugestão específica (ex.: "A foto parece ter sido ampliada demais (zoom digital) — tente se aproximar mais ou usar menos zoom."). Se false, use null.

---

#### ✏️ **5. Estilo de escrita**

* **pontos_positivos:** linguagem sensível e descritiva.
* **correcoes_sugeridas:** objetiva e prática (ex.: "suavizar sombras duras no rosto", "A foto parece ter sido ampliada demais — tente usar menos zoom ou se aproximar mais"). Horizonte só se **visivelmente torto**.
* **observacao:** curta, respeitosa e motivadora.

---

#### 🚨 **Regras absolutas finais**

* Se 'correcoes_sugeridas' estiver vazio → **score = 10.00**
* **NUNCA** sugerir contraste. Nem "leve", nem "sutil". PROIBIDO.
* **NUNCA** sugerir enquadramento. São fotos artísticas — a escolha de corte é intencional. PROIBIDO.
* **QUALIDADE:** Se pixelação/borrão forem evidentes → correção OBRIGATÓRIA e específica sobre qualidade. NUNCA "luz ou foco" nesses casos.
* Nunca inventar defeitos
* Nunca sugerir horizonte sem horizonte
* Respeitar intenção artística
* Determinismo total
* Cuidado ao usar "reduzir distrações no fundo" — só use se realmente houver muitas distrações. Às vezes a foto precisa do contexto.
* Fotos macro normalmente não são tão focadas nas laterais — não peça ajuste sobre isso quando a categoria for macro`;

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: 'gpt-4o',
      messages: [
        { role: 'system', content: systemPrompt },
        {
          role: 'user',
          content: [
            { type: 'text', text: 'Analise esta foto. PRIMEIRO: verifique se há pixelação, borrão ou perda de nitidez em toda a imagem. Se houver, preencha qualidade_comprometida=true e correcao_qualidade com a sugestão específica (zoom, recorte ou resolução). Responda em português brasileiro.' },
            {
              type: 'image_url',
              image_url: { url: `data:image/jpeg;base64,${imageBase64}` }
            }
          ]
        }
      ],
      max_tokens: 1000,
      temperature: 0.2
    })
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`OpenAI API error: ${error}`);
  }

  const data = await response.json();
  const content = data.choices[0]?.message?.content;
  if (!content) {
    throw new Error('Resposta da OpenAI inválida');
  }

  const jsonMatch = content.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    throw new Error('Não foi possível extrair JSON da resposta');
  }

  let result: { score: number; pontos_positivos: string[]; correcoes_sugeridas: string[]; observacao?: string; categoria?: string; qualidade_comprometida?: boolean; correcao_qualidade?: string | null };
  try {
    result = JSON.parse(jsonMatch[0]);
  } catch (e) {
    throw new Error('Erro ao fazer parse do JSON: ' + e);
  }

  // Validar e garantir que score está entre 0 e 10
  result.score = Math.max(0, Math.min(10, Number(result.score)));

  // Garantir arrays
  result.pontos_positivos = Array.isArray(result.pontos_positivos) ? result.pontos_positivos : [];
  result.correcoes_sugeridas = Array.isArray(result.correcoes_sugeridas) ? result.correcoes_sugeridas : [];

  // ✅ Se qualidade_comprometida e correcao_qualidade preenchidos, garantir que está em correcoes_sugeridas
  const qualidadeComprometida = result.qualidade_comprometida === true;
  const correcaoQualidade = typeof result.correcao_qualidade === 'string' && result.correcao_qualidade.trim().length > 0
    ? result.correcao_qualidade.trim()
    : null;

  if (qualidadeComprometida && correcaoQualidade && !result.correcoes_sugeridas.includes(correcaoQualidade)) {
    result.correcoes_sugeridas.unshift(correcaoQualidade);
  }

  // ✅ Se score >= 9.8 e todas correções são leves → 10.00 e limpa correções
  normalizarScoreSeCorrecoesLeves(result);

  // ✅ Filtrar correções proibidas (fallback pós-IA)
  result.correcoes_sugeridas = result.correcoes_sugeridas.filter(c => {
    const lower = c.toLowerCase();
    if (/\bcontraste\b/i.test(c)) return false;
    if (/\benquadramento\b/i.test(c)) return false;
    if (/evitar corte|melhorar.*corte|recortar/i.test(c)) return false;
    return true;
  });

  // ✅ Regra: score >= 9.8 e correções vazias → 10.00 (inconsistente ter 9.8 sem sugestão real)
  if (result.score >= 9.8 && result.correcoes_sugeridas.length === 0) {
    result.score = 10;
  }

  // ✅ Regra: se score < 10 e correções vazias → priorizar qualidade, senão fallback genérico
  if (result.score < 10 && result.correcoes_sugeridas.length === 0) {
    if (qualidadeComprometida) {
      result.correcoes_sugeridas.push(
        correcaoQualidade || "A qualidade da imagem parece comprometida (zoom ou recorte excessivo) — tente fotografar com menor ampliação para preservar a nitidez."
      );
    } else {
      result.correcoes_sugeridas.push(
        "Refinar pequenos detalhes técnicos (luz ou foco) para elevar a foto ao nível máximo."
      );
    }
  }

  // ✅ Regra: se score = 10, correções obrigatoriamente vazias
  if (result.score === 10) {
    result.correcoes_sugeridas = [];
  }

  // Garantir categoria
  result.categoria = result.categoria || 'geral';

  // Limitar arrays a 4 itens
  if (result.pontos_positivos.length > 4) {
    result.pontos_positivos = result.pontos_positivos.slice(0, 4);
  }
  if (result.correcoes_sugeridas.length > 4) {
    result.correcoes_sugeridas = result.correcoes_sugeridas.slice(0, 4);
  }

  return result;
}

Deno.serve(async (req) => {
  try {
    // Verificar método
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Método não permitido' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Obter token de autenticação
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Não autenticado' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Criar cliente Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Verificar autenticação
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Token inválido' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Obter dados da requisição
    const body = await req.json();
    const { image_base64, image_url, is_shared, user_id } = body;

    // Validar que temos pelo menos uma forma de obter a imagem
    if (!image_base64 && !image_url) {
      return new Response(JSON.stringify({ error: 'image_base64 ou image_url é obrigatório' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Priorizar image_base64 se disponível, caso contrário usar image_url
    let imageBase64: string;
    if (image_base64) {
      imageBase64 = image_base64;
    } else {
      // Baixar imagem do Storage
      const imageResponse = await fetch(image_url);
      if (!imageResponse.ok) {
        return new Response(JSON.stringify({ error: 'Erro ao baixar imagem' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        });
      }
      const imageBlob = await imageResponse.blob();
      const arrayBuffer = await imageBlob.arrayBuffer();
      imageBase64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)));
    }

    // Avaliar foto com IA
    const evaluation = await evaluatePhotoWithAI(imageBase64);

    // Converter formato da resposta para o formato do banco
    const positivePoints = Array.isArray(evaluation.pontos_positivos) ? evaluation.pontos_positivos : [];
    const improvementPoints = Array.isArray(evaluation.correcoes_sugeridas) ? evaluation.correcoes_sugeridas : [];

    // Calcular recado baseado na nota
    const recado = calcularRecado(parseFloat(String(evaluation.score)));

    // Usar image_url se fornecido, caso contrário gerar URL do Storage
    const finalImageUrl = image_url || '';

    // Validar que temos image_url antes de salvar
    if (!finalImageUrl) {
      return new Response(JSON.stringify({ error: 'image_url é obrigatório para salvar no banco' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Salvar resultado no banco
    const photoData = {
      user_id: user_id || user.id,
      image_url: finalImageUrl,
      score: parseFloat(String(evaluation.score)),
      positive_points: positivePoints,
      improvement_points: improvementPoints,
      observacao: evaluation.observacao || null,
      categoria: evaluation.categoria || null,
      recado: recado,
      is_shared: is_shared || false,
      likes_count: 0,
      comments_count: 0
    };

    const { data: photo, error: dbError } = await supabase.from('photos').insert(photoData).select().single();
    if (dbError) {
      console.error('Erro ao salvar foto:', dbError);
      return new Response(JSON.stringify({ error: 'Erro ao salvar foto no banco: ' + dbError.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Atualizar ambas as tabelas mensais no servidor (não depende do app estar aberto)
    const effectiveUserId = user_id || user.id;

    const { error: scoreError } = await supabase.rpc('update_user_photo_score', {
      p_user_id: effectiveUserId,
      p_score: parseFloat(String(evaluation.score))
    });
    if (scoreError) {
      console.error('Erro ao atualizar pontuação:', scoreError);
      return new Response(JSON.stringify({ error: 'Erro ao atualizar pontuação: ' + scoreError.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Consumo da avaliação: prioridade para extras, depois plano mensal
    const { data: extraCount } = await supabase.rpc('get_user_extra_count', {
      p_user_id: effectiveUserId
    });
    const hasExtras = (extraCount as number | null) != null && (extraCount as number) > 0;

    if (hasExtras) {
      const { error: decrementError } = await supabase.rpc('decrement_user_extra_evaluation', {
        p_user_id: effectiveUserId
      });
      if (decrementError) {
        console.error('Erro ao decrementar avaliação extra:', decrementError);
        return new Response(JSON.stringify({ error: 'Erro ao consumir avaliação extra: ' + decrementError.message }), {
          status: 500,
          headers: { 'Content-Type': 'application/json' }
        });
      }
    } else {
      const { error: evalError } = await supabase.rpc('increment_monthly_evaluation', {
        p_user_id: effectiveUserId
      });
      if (evalError) {
        console.error('Erro ao atualizar avaliações mensais:', evalError);
        return new Response(JSON.stringify({ error: 'Erro ao atualizar avaliações mensais: ' + evalError.message }), {
          status: 500,
          headers: { 'Content-Type': 'application/json' }
        });
      }
    }

    return new Response(JSON.stringify({
      success: true,
      photo: photo,
      evaluation: {
        score: evaluation.score,
        pontos_positivos: positivePoints,
        correcoes_sugeridas: improvementPoints,
        observacao: evaluation.observacao,
        categoria: evaluation.categoria
      }
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Erro na função:', error);
    return new Response(JSON.stringify({ error: (error as Error).message || 'Erro interno do servidor' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
});
