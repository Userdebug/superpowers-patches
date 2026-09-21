import test from 'node:test';
import assert from 'node:assert/strict';

import {
  extractAndStripFrontmatter,
  buildBootstrapContent,
  applyBootstrap,
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