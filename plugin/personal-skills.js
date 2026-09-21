import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';

export const extractAndStripFrontmatter = (content) => {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return content;
  return match[2];
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

export const buildBootstrapContent = (body, toolMapping) =>
  `<EXTREMELY_IMPORTANT>\n` +
  `You have superpowers.\n\n` +
  `**IMPORTANT: The using-superpowers skill content is included below. It is ALREADY LOADED - you are currently following it. Do NOT use the skill tool to load "using-superpowers" again - that would be redundant.**\n\n` +
  `${body}\n\n` +
  `${toolMapping}\n` +
  `</EXTREMELY_IMPORTANT>`;

const readBootstrap = (personalDir) => {
  const hub = path.join(personalDir, 'using-superpowers', 'SKILL.md');
  if (!fs.existsSync(hub)) return null;
  const body = extractAndStripFrontmatter(fs.readFileSync(hub, 'utf8'));
  return buildBootstrapContent(body, TOOL_MAPPING);
};

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

export const PersonalSkillsPlugin = async () => {
  const configDir = process.env.OPENCODE_CONFIG_DIR
    ? path.resolve(process.env.OPENCODE_CONFIG_DIR.trim())
    : path.join(os.homedir(), '.config', 'opencode');
  const personalSkillsDir = path.join(configDir, 'personal-skills');
  return {
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(personalSkillsDir)) {
        config.skills.paths.push(personalSkillsDir);
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