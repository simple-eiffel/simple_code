# simple_code

**AI-Powered Code Assistant Integration for Eiffel**

A library for integrating AI assistants (Claude Code, Ollama/Llama3, and others) with EiffelStudio and Eiffel development workflows.

## Vision

simple_code bridges the gap between modern AI coding assistants and the Eiffel development environment, providing:

- **EiffelStudio Tool Panel**: Dockable AI assistant panel integrated directly into the IDE
- **Multi-Provider Support**: Claude API, Ollama (local), and extensible provider architecture
- **Context-Aware Assistance**: Understands Eiffel syntax, DBC contracts, and OOSC2 principles
- **Code Generation**: Generate Eiffel code following simple_* ecosystem patterns

## Status

**Phase 0**: Project skeleton and documentation

## Documentation

- [EiffelStudio Tool Development Guide](docs/EIFFELSTUDIO_TOOL_DEVELOPMENT.md) - Comprehensive guide for creating custom IDE panels

## Planned Features

### Phase 1: Core Infrastructure
- [ ] AI provider abstraction layer
- [ ] HTTP client wrapper for API calls
- [ ] Response streaming support
- [ ] Configuration management

### Phase 2: Provider Implementations
- [ ] Claude API integration (Opus, Sonnet, Haiku)
- [ ] Ollama local integration (Llama3, CodeLlama, etc.)
- [ ] Provider switching and fallback

### Phase 3: EiffelStudio Integration
- [ ] Dockable tool panel (ES_DOCKABLE_TOOL_WINDOW)
- [ ] Editor context extraction
- [ ] Stone protocol for class/feature targeting
- [ ] Keyboard shortcuts

### Phase 4: Eiffel Intelligence
- [ ] Contract-aware code generation
- [ ] Eiffel syntax understanding
- [ ] simple_* pattern awareness
- [ ] Test generation from contracts

## Architecture

```
simple_code/
+-- src/
|   +-- providers/           # AI provider implementations
|   |   +-- sc_provider.e    # Abstract provider
|   |   +-- sc_claude.e      # Claude API
|   |   +-- sc_ollama.e      # Ollama local
|   +-- tool/                # EiffelStudio integration
|   |   +-- es_code_assistant_tool.e
|   +-- core/                # Core classes
|       +-- sc_message.e
|       +-- sc_conversation.e
|       +-- sc_config.e
+-- docs/
+-- testing/
```

## Dependencies

- simple_http (HTTP client)
- simple_json (JSON parsing)
- EiffelStudio libraries (for IDE integration)

## License

MIT License

## Author

Larry Reid (simple-eiffel ecosystem)
