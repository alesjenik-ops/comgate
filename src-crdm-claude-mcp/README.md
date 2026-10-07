# Claude MCP – External Client App (CRDM)

External Client App `Claude_MCP` pro připojení Claude (claude.ai) k Salesforce hosted
MCP serverům. Nasazeno do CRDM 7. 10. 2026.

| Nastavení | Hodnota |
| --- | --- |
| Callback URL | `https://claude.ai/api/mcp/auth_callback`, `https://claude.com/api/mcp/auth_callback` |
| Scopes | MCP, RefreshToken (`refresh_token, offline_access`) |
| Zabezpečení | PKCE povinné, JWT access tokeny pro named users, secret povinný i při obnově tokenu, rotace refresh tokenu |
| Policies | všichni uživatelé se smí sami autorizovat, IP omezení uvolněná, refresh token platí do odvolání |

Aktivní MCP servery v CRDM: `sobject-all`, `metadata-experts`, `headless-360`.

Consumer Key a Secret se metadaty nepřenášejí: Setup → External Client App Manager →
Claude MCP → Settings → OAuth Settings → *Consumer Key and Secret*.

V claude.ai: Customize → Connectors → Add custom connector, URL např.
`https://api.salesforce.com/platform/mcp/v1/platform/sobject-all`, v Advanced settings
Consumer Key jako Client ID a Consumer Secret jako Client Secret.

```bash
sf project deploy start --metadata-dir src-crdm-claude-mcp --target-org <alias>
```
