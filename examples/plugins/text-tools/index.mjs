import { randomUUID } from 'node:crypto';

export default {
  tools: {
    transform: {
      async execute({ text }) {
        if (!text) return { items: [] };
        const items = [
          { id: 'url-encode', title: encodeURIComponent(text), subtitle: 'URL Encode', copy: encodeURIComponent(text) },
          { id: 'base64', title: Buffer.from(text, 'utf8').toString('base64'), subtitle: 'Base64 Encode', copy: Buffer.from(text, 'utf8').toString('base64') },
        ];
        try {
          const decoded = decodeURIComponent(text);
          if (decoded !== text) items.push({ id: 'url-decode', title: decoded, subtitle: 'URL Decode', copy: decoded });
        } catch { /* Incomplete escapes are normal while typing. */ }
        return { items };
      },
    },
    uuid: {
      async execute() { return { text: randomUUID() }; },
    },
  },
};
