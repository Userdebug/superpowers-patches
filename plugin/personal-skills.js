import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';

/**
 * Plugin personnel dual V1/V2 (miroir du pattern obra/superpowers v7).
 *
 * V1 (OpenCode 1.x) : export nommé PersonalSkillsPlugin — hook config
 *   (skills.paths + glob d'instructions) + experimental.chat.messages.transform
 *   pour l'injection/remplacement du bootstrap.
 * V2 (OpenCode 2.x) : default export { id, server, setup } — setup() enregistre
 *   les skills via ctx.skill.transform() (après superpowers ⇒ nos versions
 *   gagnent, Map.set remplace à id identique) et injecte le bootstrap via
 *   ctx.session.hook("context") avec le mapping d'outils V2.
 *
 * Le chemin V1 (server) reste inchangé pour garantir le rollback.
 */

export const extractAndStripFrontmatter = (content) => {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return content;
  return match[2];
};

// Parseur de frontmatter tolérant, calqué sur obra/superpowers v7 :
// lignes clé: valeur, valeurs quoted se fermant sur une continuation, scalaires
// de bloc YAML (>, |), CRLF. Pas un parseur YAML complet — seuls les champs
// name/description consommés par Skill.Info sont lus.
export const parseSkillFrontmatter = (content) => {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!match) return { frontmatter: {}, content };

  const frontmatterStr = match[1];
  const body = match[2];
  const frontmatter = {};
  let lastKey = null;

  for (const rawLine of frontmatterStr.split('\n')) {
    const line = rawLine.replace(/\r$/, '');
    const colonIdx = line.indexOf(':');
    if (colonIdx > 0 && !/^\s/.test(line)) {
      const key = line.slice(0, colonIdx).trim();
      const value = line.slice(colonIdx + 1).trim();
      frontmatter[key] = /^(>[+-]?|\|[+-]?)$/.test(value) ? '' : value;
      lastKey = key;
    } else if (lastKey !== null && line.trim() !== '') {
      frontmatter[lastKey] = `${frontmatter[lastKey]} ${line.trim()}`.trim();
    }
  }

  for (const key of Object.keys(frontmatter)) {
    frontmatter[key] = frontmatter[key].replace(/^(["'])([\s\S]*)\1$/, '$2');
  }

  return { frontmatter, content: body };
};

const TOOL_MAPPING = `**Tool Mapping for OpenCode:**
When skills request actions, substitute OpenCode equivalents:
- Create or update todos → \`todowrite\`
- \`Subagent (general-purpose):\` → \`task\` with \`subagent_type: "general"\`
- Invoke a skill → OpenCode's native \`skill\` tool
- Read files → \`read\`
- Create, edit, or delete files → \`apply_patch\`
- Run shell commands → \`bash\`
- Search files → \`grep\`, \`glob\`
- Fetch a URL → \`webfetch\`

Use OpenCode's native \`skill\` tool to list and load skills.`;

// Mapping d'outils V2, repris verbatim de superpowers v7 : les outils built-in
// changent de nom/shape sous OpenCode 2 (pas de todowrite, task→subagent,
// bash→shell, apply_patch→patch/write/edit).
export const V2_TOOL_MAPPING = `**Tool Mapping for OpenCode:**
When skills request actions, substitute OpenCode equivalents:
- Create or update todos → OpenCode v2 has no todo tool; track the plan in a markdown file (or the harness's plan facility) instead
- \`Subagent (general-purpose):\` → \`subagent\` with \`agent: "general"\` (give it \`description\` and \`prompt\`, optionally \`background\`; pass \`sessionID\` to continue a previous subagent)
- Invoke a skill → OpenCode's native \`skill\` tool
- Read files → \`read\`
- Create, edit, or delete files → use \`patch\` with \`patchText\` when available; otherwise use \`write\` to create or overwrite files, \`edit\` for targeted changes, and \`shell\` for deletion
- Run shell commands → \`shell\` (\`command\`, \`workdir\`, \`timeout\`, \`background\`)
- Search files → \`grep\`, \`glob\`
- Fetch a URL → \`webfetch\`
- Search the web → \`websearch\`

Use OpenCode's native \`skill\` tool to list and load skills.`;

export const buildBootstrapContent = (body, toolMapping) =>
  `<EXTREMELY_IMPORTANT>\n` +
  `You have superpowers.\n\n` +
  `**IMPORTANT: The using-superpowers skill content is included below. It is ALREADY LOADED - you are currently following it. Do NOT use the skill tool to load "using-superpowers" again - that would be redundant.**\n\n` +
  `${body}\n\n` +
  `${toolMapping}\n` +
  `</EXTREMELY_IMPORTANT>`;

// Cache par mapping d'outils (une entrée par flavor de host) : le SKILL.md ne
// change pas en cours de session.
const bootstrapCache = new Map();

const readBootstrap = (personalDir, toolMapping = TOOL_MAPPING) => {
  if (bootstrapCache.has(toolMapping)) return bootstrapCache.get(toolMapping);
  const hub = path.join(personalDir, 'using-superpowers', 'SKILL.md');
  if (!fs.existsSync(hub)) {
    bootstrapCache.set(toolMapping, null);
    return null;
  }
  const body = extractAndStripFrontmatter(fs.readFileSync(hub, 'utf8'));
  const bootstrap = buildBootstrapContent(body, toolMapping);
  bootstrapCache.set(toolMapping, bootstrap);
  return bootstrap;
};

// --- Injection V1 (shape { info: { role }, parts }) --------------------------
export const applyBootstrap = (messages, bootstrap) => {
  const firstUser = messages.find((m) => m.info && m.info.role === 'user');
  if (!firstUser || !firstUser.parts || !firstUser.parts.length) return;
  const existing = firstUser.parts.find((p) => p.type === 'text' && p.text.includes('EXTREMELY_IMPORTANT'));
  if (existing) {
    existing.text = bootstrap;
    return;
  }
  const ref = firstUser.parts[0];
  firstUser.parts.unshift({ ...ref, type: 'text', text: bootstrap });
};

// --- Injection V2 (shape { role, content: [{ type: 'text', text }] }) --------
// Même sémantique que V1 : remplace le bootstrap existant (notre version gagne
// sur celle de superpowers), sinon insère en tête ; si aucun message user
// (post-compaction, checkpoint opaque), append un message user.
export const applyBootstrapV2 = (messages, bootstrap) => {
  if (!Array.isArray(messages) || !messages.length) return;
  const firstUser = messages.find((m) => m && m.role === 'user');
  if (firstUser && (!Array.isArray(firstUser.content) || !firstUser.content.length)) return;
  if (firstUser) {
    const existing = firstUser.content.find(
      (p) => p && p.type === 'text' && typeof p.text === 'string' && p.text.includes('EXTREMELY_IMPORTANT'),
    );
    if (existing) {
      existing.text = bootstrap;
      return;
    }
    firstUser.content.unshift({ type: 'text', text: bootstrap });
    return;
  }
  messages.push({ role: 'user', content: [{ type: 'text', text: bootstrap }] });
};

// --- Détection sessions-enfant (superpowers #2160) ---------------------------
// Le bootstrap pilote les workflows contrôleur (brainstorming, plans, cycles
// d'approbation) : l'injecter dans une session task-subagent fait redémarrer
// ces cycles dans un worker. Signal structurel : parentID présent sur la
// session. Fail-open sur erreur de lookup (on injecte, comme avant).
const CHILD_SESSION_CACHE_MAX = 512;
const _childSessionCache = new Map();

const _cacheChildSession = (sessionID, isChild) => {
  if (_childSessionCache.size >= CHILD_SESSION_CACHE_MAX) {
    let toDrop = Math.ceil(CHILD_SESSION_CACHE_MAX / 4);
    for (const key of _childSessionCache.keys()) {
      if (toDrop-- <= 0) break;
      _childSessionCache.delete(key);
    }
  }
  _childSessionCache.set(sessionID, isChild);
};

export const isChildSession = async (fetchSession, sessionID) => {
  if (!sessionID) return false;
  if (_childSessionCache.has(sessionID)) return _childSessionCache.get(sessionID);

  let isChild = false;
  try {
    const result = await fetchSession(sessionID);
    if (!result || typeof result !== 'object' || Array.isArray(result)) {
      throw new Error('Session lookup returned no usable record');
    }
    if (result.error != null || result.response?.ok === false) {
      throw new Error('Session lookup was unsuccessful');
    }
    const session = 'data' in result ? result.data : result;
    if (!session || typeof session !== 'object' || Array.isArray(session) || session.id !== sessionID) {
      throw new Error('Session lookup returned an invalid session identity');
    }
    if (session.parentID !== undefined &&
        (typeof session.parentID !== 'string' || session.parentID.length === 0)) {
      throw new Error('Session lookup returned an invalid parent identity');
    }
    isChild = session.parentID !== undefined;
  } catch (err) {
    console.error('[personal-skills] session lookup failed, treating session as top-level:', err);
    return false;
  }
  _cacheChildSession(sessionID, isChild);
  return isChild;
};

const resolveConfigDir = () =>
  process.env.OPENCODE_CONFIG_DIR
    ? path.resolve(process.env.OPENCODE_CONFIG_DIR.trim())
    : path.join(os.homedir(), '.config', 'opencode');

// --- V1 : Plugin function (export nommé PersonalSkillsPlugin) ---------------
// INCHANGÉ — chemin de rollback. Fournit le hook config (skills.paths + glob
// d'instructions) et l'injection bootstrap via messages.transform.
export const PersonalSkillsPlugin = async () => {
  const configDir = resolveConfigDir();
  const personalSkillsDir = path.join(configDir, 'personal-skills');
  const instructionGlob = '.opencode/instructions/*.md';
  return {
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(personalSkillsDir)) {
        config.skills.paths.push(personalSkillsDir);
      }
      config.instructions = config.instructions || [];
      if (!config.instructions.includes(instructionGlob)) {
        config.instructions.push(instructionGlob);
      }
    },
    'experimental.chat.messages.transform': async (_input, output) => {
      if (!output.messages || !output.messages.length) return;
      const bootstrap = readBootstrap(personalSkillsDir);
      if (!bootstrap) return;
      applyBootstrap(output.messages, bootstrap);
    },
  };
};

// --- V2 : setup(ctx) ---------------------------------------------------------
// 1. skills via ctx.skill.transform — enregistré APRÈS superpowers (ordre de
//    config plugins), et editor.add = Map.set : à id identique, notre version
//    remplace la leur (invariant « patch personnel gagne »).
// 2. bootstrap via ctx.session.hook("context") — remplace le bootstrap
//    superpowers s'il est déjà présent, sinon insère (sauf sessions-enfant).
async function setup(ctx) {
  // V1 peut aussi invoquer default.setup avec un ctx V1 dépourvu des domaines
  // skill/session — retour silencieux, le chemin V1 sert via server().
  if (!ctx || !ctx.skill || typeof ctx.skill.transform !== 'function' ||
      !ctx.session || typeof ctx.session.hook !== 'function') {
    return;
  }

  const configDir = resolveConfigDir();
  const personalSkillsDir = path.join(configDir, 'personal-skills');

  // 1. Enregistrement des skills du miroir personnel
  try {
    const skills = [];
    if (fs.existsSync(personalSkillsDir)) {
      for (const entry of fs.readdirSync(personalSkillsDir, { withFileTypes: true })) {
        if (!entry.isDirectory() || entry.name.startsWith('.')) continue;
        const skillPath = path.join(personalSkillsDir, entry.name, 'SKILL.md');
        if (!fs.existsSync(skillPath)) continue;
        const { frontmatter, content } = parseSkillFrontmatter(fs.readFileSync(skillPath, 'utf8'));
        skills.push({
          id: entry.name,
          name: frontmatter.name || entry.name,
          ...(frontmatter.description ? { description: frontmatter.description } : {}),
          path: skillPath,
          content,
        });
      }
    }
    await ctx.skill.transform((draft) => {
      // draft.add lève synchronisement sur payload invalide ; une fuite tuerait
      // tout le plugin (skills + bootstrap) — on isole l'échec par skill.
      for (const skill of skills) {
        try {
          draft.add(skill);
        } catch (err) {
          console.error(`[personal-skills] skill "${skill.id}" rejected by host, skipping:`, err);
        }
      }
    });
  } catch (err) {
    console.error('[personal-skills] skill registration failed:', err);
  }

  // 2. Injection/remplacement du bootstrap dans le premier message user
  try {
    await ctx.session.hook('context', async (event) => {
      try {
        const bootstrap = readBootstrap(personalSkillsDir, V2_TOOL_MAPPING);
        if (!bootstrap || !event.messages || !event.messages.length) return;
        const firstUser = event.messages.find((m) => m && m.role === 'user');
        if (firstUser && (!Array.isArray(firstUser.content) || !firstUser.content.length)) return;
        const hasBootstrap = !!firstUser && firstUser.content.some(
          (p) => p && p.type === 'text' && typeof p.text === 'string' && p.text.includes('EXTREMELY_IMPORTANT'),
        );
        // Pas de bootstrap présent ⇒ session potentiellement enfant : ne jamais
        // injecter le contrôleur dans un worker (superpowers #2160). Le chemin
        // « remplacer » reste autorisé partout (remplacer = gagner, sans
        // réinjecter dans les enfants : superpowers n'y en met jamais).
        if (!hasBootstrap && typeof ctx.session.get === 'function' && await isChildSession(
          (id) => ctx.session.get({ sessionID: id }),
          event.sessionID,
        )) return;
        applyBootstrapV2(event.messages, bootstrap);
      } catch (err) {
        console.error('[personal-skills] context hook failed:', err);
      }
    });
  } catch (err) {
    console.error('[personal-skills] session hook registration failed:', err);
  }

  // Note : le glob d'instructions du triptyque (.opencode/instructions/*.md)
  // n'a pas de domaine ctx.* en V2 — il est déclaré directement dans
  // opencode.json(c) (champ instructions, forme identique v1/v2).
}

/**
 * Default export : { id, server, setup }.
 * V2 lit id + setup (ignore server) ; V1 sert via l'export nommé, avec
 * repli sur server() selon la version.
 */
export default {
  id: 'personal-skills',
  server: PersonalSkillsPlugin,
  setup,
};
