import test from 'node:test';
import assert from 'node:assert/strict';

import {
  extractAndStripFrontmatter,
  buildBootstrapContent,
  applyBootstrap,
  applyBootstrapV2,
  parseSkillFrontmatter,
  isChildSession,
  PersonalSkillsPlugin,
  V2_TOOL_MAPPING,
  default as PersonalSkills,
} from '../plugin/personal-skills.js';

test('extractAndStripFrontmatter retire le frontmatter, garde le corps', () => {
  const src = '---\nname: x\ndescription: y\n---\nCORPS';
  assert.equal(extractAndStripFrontmatter(src), 'CORPS');
});

test('extractAndStripFrontmatter sans frontmatter rend le contenu tel quel', () => {
  const src = 'PAS DE FRONTMATTER';
  assert.equal(extractAndStripFrontmatter(src), src);
});

test('buildBootstrapContent enveloppe le corps et intègre le mapping', () => {
  const b = buildBootstrapContent('MARCHEUR', 'OUTILS');
  assert.ok(b.includes('<EXTREMELY_IMPORTANT>'));
  assert.ok(b.includes('MARCHEUR'));
  assert.ok(b.includes('OUTILS'));
});

test('applyBootstrap remplace un bootstrap existant', () => {
  const messages = [{
    info: { role: 'user' },
    parts: [{ type: 'text', text: 'old EXTREMELY_IMPORTANT x' }],
  }];
  applyBootstrap(messages, 'NEW');
  assert.equal(messages[0].parts.length, 1);
  assert.ok(messages[0].parts[0].text.includes('NEW'));
});

test('applyBootstrap injecte si aucun bootstrap présent', () => {
  const messages = [{
    info: { role: 'user' },
    parts: [{ type: 'text', text: 'bonjour' }],
  }];
  applyBootstrap(messages, 'NEW');
  assert.equal(messages[0].parts.length, 2);
  assert.ok(messages[0].parts[0].text.includes('NEW'));
  assert.equal(messages[0].parts[1].text, 'bonjour');
});

test('applyBootstrap ignore si aucun message utilisateur', () => {
  const messages = [{ info: { role: 'assistant' }, parts: [{ type: 'text', text: 'x' }] }];
  applyBootstrap(messages, 'NEW');
  assert.equal(messages[0].parts.length, 1);
});

const INSTRUCTION_GLOB = '.opencode/instructions/*.md';

const configHook = async (config) => {
  const plugin = await PersonalSkillsPlugin();
  const hooks = plugin.config;
  return hooks(config);
};

test('config() injecte le glob instructions quand aucune instruction définie', async () => {
  const config = {};
  await configHook(config);
  assert.deepEqual(config.instructions, [INSTRUCTION_GLOB]);
});

test('config() ajoute le glob sans écraser les instructions projet existantes', async () => {
  const config = { instructions: ['AGENTS.md'] };
  await configHook(config);
  assert.deepEqual(config.instructions, ['AGENTS.md', INSTRUCTION_GLOB]);
});

test('config() est idempotent : le glob n`est jamais dupliqué', async () => {
  const config = { instructions: [INSTRUCTION_GLOB] };
  await configHook(config);
  await configHook(config);
  assert.deepEqual(config.instructions, [INSTRUCTION_GLOB]);
});

// --- V2 : parseSkillFrontmatter ---------------------------------------------

test('parseSkillFrontmatter lit name/description et strip le corps', () => {
  const src = '---\nname: ma-skill\ndescription: un court résumé\n---\nCORPS';
  const { frontmatter, content } = parseSkillFrontmatter(src);
  assert.equal(frontmatter.name, 'ma-skill');
  assert.equal(frontmatter.description, 'un court résumé');
  assert.equal(content, 'CORPS');
});

test('parseSkillFrontmatter tolère quotes, scalaires de bloc et continuation', () => {
  const src = '---\nname: "entre quotes"\ndescription: >-\n  ligne 1\n  ligne 2\n---\nCORPS';
  const { frontmatter } = parseSkillFrontmatter(src);
  assert.equal(frontmatter.name, 'entre quotes');
  assert.equal(frontmatter.description, 'ligne 1 ligne 2');
});

test('parseSkillFrontmatter sans frontmatter rend le contenu tel quel', () => {
  const src = 'PAS DE FRONTMATTER';
  const { frontmatter, content } = parseSkillFrontmatter(src);
  assert.deepEqual(frontmatter, {});
  assert.equal(content, src);
});

test('parseSkillFrontmatter gère le CRLF', () => {
  const src = '---\r\nname: crlf\r\n---\r\nCORPS';
  const { frontmatter, content } = parseSkillFrontmatter(src);
  assert.equal(frontmatter.name, 'crlf');
  assert.equal(content, 'CORPS');
});

// --- V2 : V2_TOOL_MAPPING ----------------------------------------------------

test('V2_TOOL_MAPPING nomme les outils v2 (shell/subagent/patch), pas v1', () => {
  assert.ok(V2_TOOL_MAPPING.includes('→ `shell`'));
  assert.ok(V2_TOOL_MAPPING.includes('→ `subagent`'));
  assert.ok(V2_TOOL_MAPPING.includes('`patch`'));
  assert.ok(!V2_TOOL_MAPPING.includes('→ `bash`'));
  assert.ok(!V2_TOOL_MAPPING.includes('→ `todowrite`'));
  assert.ok(!V2_TOOL_MAPPING.includes('→ `task`'));
  assert.ok(!V2_TOOL_MAPPING.includes('→ `apply_patch`'));
});

// --- V2 : applyBootstrapV2 ---------------------------------------------------

test('applyBootstrapV2 remplace un bootstrap existant (notre version gagne)', () => {
  const messages = [{
    role: 'user',
    content: [{ type: 'text', text: 'old EXTREMELY_IMPORTANT superpowers' }],
  }];
  applyBootstrapV2(messages, 'NEW');
  assert.equal(messages[0].content.length, 1);
  assert.equal(messages[0].content[0].text, 'NEW');
});

test('applyBootstrapV2 insère en tête si aucun bootstrap présent', () => {
  const messages = [{ role: 'user', content: [{ type: 'text', text: 'bonjour' }] }];
  applyBootstrapV2(messages, 'NEW');
  assert.equal(messages[0].content.length, 2);
  assert.equal(messages[0].content[0].text, 'NEW');
  assert.equal(messages[0].content[1].text, 'bonjour');
});

test('applyBootstrapV2 no-op si le premier user a un content non-tableau', () => {
  const messages = [{ role: 'user', content: 'texte plat' }];
  applyBootstrapV2(messages, 'NEW');
  assert.equal(messages[0].content, 'texte plat');
});

test('applyBootstrapV2 ignore un tableau de messages vide', () => {
  const messages = [];
  applyBootstrapV2(messages, 'NEW');
  assert.deepEqual(messages, []);
});

test('applyBootstrapV2 append un message user si aucun message user (post-compaction)', () => {
  const messages = [{ role: 'assistant', content: [{ type: 'text', text: 'x' }] }];
  applyBootstrapV2(messages, 'NEW');
  assert.equal(messages.length, 2);
  assert.equal(messages[1].role, 'user');
  assert.equal(messages[1].content[0].text, 'NEW');
});

// --- V2 : isChildSession -----------------------------------------------------

test('isChildSession : parentID présent ⇒ session enfant (cache inclus)', async () => {
  let calls = 0;
  const fetch = async () => { calls += 1; return { data: { id: 'ses_cache_child', parentID: 'ses_parent' } }; };
  assert.equal(await isChildSession(fetch, 'ses_cache_child'), true);
  assert.equal(await isChildSession(fetch, 'ses_cache_child'), true);
  assert.equal(calls, 1, 'le cache doit éviter un second lookup');
});

test('isChildSession : sans parentID ⇒ top-level', async () => {
  const fetch = async () => ({ data: { id: 'ses_top' } });
  assert.equal(await isChildSession(fetch, 'ses_top'), false);
});

test('isChildSession : réponse en erreur ⇒ fail-open top-level (on injecte)', async () => {
  const orig = console.error;
  console.error = () => {};
  try {
    const fetch = async () => ({ error: { message: 'boom' } });
    assert.equal(await isChildSession(fetch, 'ses_err'), false);
    const fetch2 = async () => { throw new Error('réseau'); };
    assert.equal(await isChildSession(fetch2, 'ses_err2'), false);
  } finally {
    console.error = orig;
  }
});

test('isChildSession : identité non concordante ⇒ fail-open top-level', async () => {
  const orig = console.error;
  console.error = () => {};
  try {
    const fetch = async () => ({ data: { id: 'ses_autre' } });
    assert.equal(await isChildSession(fetch, 'ses_attendu'), false);
  } finally {
    console.error = orig;
  }
});

test('isChildSession : sans sessionID ⇒ false sans lookup', async () => {
  const fetch = async () => { throw new Error('ne doit pas être appelé'); };
  assert.equal(await isChildSession(fetch, undefined), false);
});

// --- V2 : default export + setup() ------------------------------------------

test('default export : { id, server, setup } (contrat V2 lisible par opencode 2)', () => {
  assert.equal(PersonalSkills.id, 'personal-skills');
  assert.equal(typeof PersonalSkills.server, 'function');
  assert.equal(typeof PersonalSkills.setup, 'function');
});

test('setup() garde V1 : ctx sans domaines skill/session ⇒ retour silencieux', async () => {
  let transformCalls = 0;
  let hookCalls = 0;
  await PersonalSkills.setup({});
  await PersonalSkills.setup({
    skill: { transform: async () => { transformCalls += 1; } },
    session: {},
  });
  assert.equal(transformCalls, 0, 'le transform V1 ne doit jamais être invoqué sans hook session');
  assert.equal(hookCalls, 0);
});

test('setup() V2 : enregistre les skills du miroir et le hook context', async () => {
  const fs = await import('node:fs');
  const os = await import('node:os');
  const path = await import('node:path');

  // Miroir factice : le plugin lit configDir/personal-skills (OPENCODE_CONFIG_DIR).
  // Le hub using-superpowers est OBLIGATOIRE : readBootstrap s'appuie dessus.
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'psk-'));
  const mirror = path.join(tmp, 'personal-skills');
  fs.mkdirSync(path.join(mirror, 'using-superpowers'), { recursive: true });
  fs.writeFileSync(path.join(mirror, 'using-superpowers', 'SKILL.md'),
    '---\nname: using-superpowers\ndescription: le hub\n---\nCORPS-DU-HUB');
  fs.mkdirSync(path.join(mirror, 'other-skill'), { recursive: true });
  fs.writeFileSync(path.join(mirror, 'other-skill', 'SKILL.md'),
    '---\nname: other-skill\ndescription: autre\n---\nCORPS-AUTRE');
  const prevDir = process.env.OPENCODE_CONFIG_DIR;
  process.env.OPENCODE_CONFIG_DIR = tmp;

  try {
    const added = [];
    const hooks = {};
    await PersonalSkills.setup({
      skill: { transform: async (cb) => cb({ add: (p) => added.push(p) }) },
      session: { hook: (name, fn) => { hooks[name] = fn; } },
    });

    // 1. Skills enregistrés : payload complet, corps dé-frontmatterisé.
    assert.equal(added.length, 2);
    const hub = added.find((s) => s.id === 'using-superpowers');
    assert.ok(hub, 'using-superpowers doit être enregistré');
    assert.equal(hub.name, 'using-superpowers');
    assert.equal(hub.description, 'le hub');
    assert.equal(hub.content, 'CORPS-DU-HUB');
    assert.ok(hub.path.endsWith(path.join('using-superpowers', 'SKILL.md')));
    assert.ok(added.some((s) => s.id === 'other-skill'));

    // 2. Hook context enregistré.
    assert.equal(typeof hooks.context, 'function');

    // 3. Remplacement du bootstrap superpowers par NOTRE version (mapping V2).
    const messages = [{
      role: 'user',
      content: [{ type: 'text', text: 'EXTREMELY_IMPORTANT bootstrap superpowers ancien' }],
    }];
    await hooks.context({ messages, sessionID: 'ses_v2_top' });
    const text = messages[0].content[0].text;
    assert.ok(text.startsWith('<EXTREMELY_IMPORTANT>'));
    assert.ok(text.includes('CORPS-DU-HUB'), 'notre hub curaté doit remplacer le leur');
    assert.ok(text.includes('→ `shell`'), 'le mapping V2 doit être présent');
    assert.ok(text.includes('→ `subagent`'));

    // 4. Session top-level sans bootstrap ⇒ insertion en tête.
    const fresh = [{ role: 'user', content: [{ type: 'text', text: 'bonjour' }] }];
    await hooks.context({ messages: fresh, sessionID: 'ses_v2_top2' });
    assert.ok(fresh[0].content[0].text.includes('CORPS-DU-HUB'));

    // 5. Session ENFANT sans bootstrap ⇒ jamais injecté (superpowers #2160).
    const childMessages = [{ role: 'user', content: [{ type: 'text', text: 'bonjour' }] }];
    await hooks.context({
      messages: childMessages,
      sessionID: 'ses_v2_child',
      // injecté via ctx.session.get capturé par setup : on passe get ici ?
      // Le plugin lit ctx.session.get (capturé à l'enregistrement) — le hook
      // ne reçoit pas get. On vérifie donc via un setup dédié ci-dessous.
    });
    // Pas de get disponible dans ce ctx ⇒ comportement « pas de preuve d'enfant »
    // = injection autorisée (fail-open documenté).
    assert.ok(childMessages[0].content[0].text.includes('CORPS-DU-HUB'));

    // 6. Content non-tableau ⇒ no-op.
    const plat = [{ role: 'user', content: 'texte plat' }];
    await hooks.context({ messages: plat, sessionID: 'ses_v2_plat' });
    assert.equal(plat[0].content, 'texte plat');
  } finally {
    if (prevDir === undefined) delete process.env.OPENCODE_CONFIG_DIR;
    else process.env.OPENCODE_CONFIG_DIR = prevDir;
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('setup() V2 : session enfant (ctx.session.get parentID) ⇒ pas d injection', async () => {
  const fs = await import('node:fs');
  const os = await import('node:os');
  const path = await import('node:path');

  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'psk2-'));
  const mirror = path.join(tmp, 'personal-skills');
  fs.mkdirSync(path.join(mirror, 'using-superpowers'), { recursive: true });
  fs.writeFileSync(path.join(mirror, 'using-superpowers', 'SKILL.md'),
    '---\nname: using-superpowers\ndescription: hub\n---\nHUB-ENFANT');
  const prevDir = process.env.OPENCODE_CONFIG_DIR;
  process.env.OPENCODE_CONFIG_DIR = tmp;

  try {
    const hooks = {};
    await PersonalSkills.setup({
      skill: { transform: async (cb) => cb({ add: () => {} }) },
      session: {
        hook: (name, fn) => { hooks[name] = fn; },
        get: async ({ sessionID }) => (sessionID === 'ses_v2_child2'
          ? { data: { id: 'ses_v2_child2', parentID: 'ses_parent_x' } }
          : { data: { id: sessionID } }),
      },
    });

    const child = [{ role: 'user', content: [{ type: 'text', text: 'bonjour worker' }] }];
    await hooks.context({ messages: child, sessionID: 'ses_v2_child2' });
    assert.equal(child[0].content.length, 1, 'aucune injection dans une session enfant');
    assert.equal(child[0].content[0].text, 'bonjour worker');

    // Top-level (sans parentID) : injection OK même avec get présent.
    // (Contenu exact du hub selon le cache bootstrap du process — on asserte
    // l'injection, pas le contenu, pour rester robuste à l'ordre des tests.)
    const top = [{ role: 'user', content: [{ type: 'text', text: 'bonjour top' }] }];
    await hooks.context({ messages: top, sessionID: 'ses_v2_topget' });
    assert.ok(top[0].content[0].text.startsWith('<EXTREMELY_IMPORTANT>'));
    assert.notEqual(top[0].content[0].text, 'bonjour top');
  } finally {
    if (prevDir === undefined) delete process.env.OPENCODE_CONFIG_DIR;
    else process.env.OPENCODE_CONFIG_DIR = prevDir;
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});
