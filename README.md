# Bloom Filter Library for MoonBit

A high-performance Bloom filter implementation with variants and concurrency support.

## Project Status

This project is in early development stage. Currently, only basic project structure and simple syntax tests exist. Core features are planned but not yet implemented.

## Planned Features

The following features are planned but not yet implemented:

1. **Batch Operations API** - Support for bulk insert and query operations
2. **Concurrent Safety** - Thread-safe wrapper using Ref
3. **Counting Bloom Filter** - Supports deletion operations
4. **Cuckoo Filter** - Space-efficient alternative with deletion support
5. **Performance Benchmarks** - Comprehensive performance testing suite
6. **Parametric Tests** - Extensive test coverage for various configurations
7. **Memory Optimization** - Compact implementation using bit-packed arrays
8. **Documentation** - Comprehensive documentation comments

## Known Issues

Core features are not yet implemented. The project currently only contains:
- Basic project structure and configuration
- Simple MoonBit syntax tests (4 test cases)
- No actual Bloom Filter implementation

## Next Steps

1. Implement basic Bloom Filter data structure
2. Add hash function support
3. Implement basic insert and query operations
4. Add unit tests for core functionality
5. Implement Counting Bloom Filter variant
6. Implement Cuckoo Filter variant
7. Add concurrency support
8. Create performance benchmarks
9. Add comprehensive documentation

## File Structure

```
bfilter/
├── README.md                # This file
├── LICENSE                  # MIT License
├── moon.mod.json            # Project configuration
└── src/
    ├── moon.pkg.json        # Package configuration
    └── simple_test.mbt      # Basic MoonBit syntax tests (4 test cases)
```

## Testing

Currently, only basic MoonBit syntax tests exist (4 test cases). Run the tests:
```bash
moon test
```

Comprehensive functional tests will be added as features are implemented.

## Contributing

This project is in early development. Core features are not yet implemented. Contributions are welcome, especially for implementing the planned features.

## License

MIT