const std = @import("std");

/// A collection of useful alphabets that can be used to generate ids.
pub const alphabets = struct 
{    
    /// Numbers from 0 to 9.
    pub const numbers = "0123456789";

    /// English hexadecimal with lowercase characters.
    pub const hexadecimal_lowercase = numbers ++ "abcdef";

    /// English hexadecimal with uppercase characters.
    pub const hexadecimal_uppercase = numbers ++ "ABCDEF";

    /// Lowercase English letters.
    pub const lowercase = "abcdefghijklmnopqrstuvwxyz";
    
    /// Uppercase English letters.
    pub const uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    
    /// Numbers and english letters without lookalikes: 1, l, I, 0, O, o, u, v, 5, S, s, 2, Z.
    pub const no_look_alikes = "346789ABCDEFGHJKLMNPQRTUVWXYabcdefghijkmnpqrtwxyz";
    
    /// Same as nolookalikes but with removed vowels and following letters: 3, 4, x, X, V.
    /// This list should protect you from accidentally getting obscene words in generated strings.
    pub const no_look_alikes_safe = "6789BCDFGHJKLMNPQRTWbcdfghjkmnpqrtwz";

    /// Combination of all the lowercase, uppercase characters and numbers from 0 to 9. 
    /// Does not include any symbols or special characters.
    pub const alphanumeric = numbers ++ lowercase ++ uppercase;

    /// URL friendly characters used by the default generate procedure.
    pub const default = "_-" ++ alphanumeric;

    /// An array of all the alphabets.
    pub const all = [_][]const u8 { numbers, hexadecimal_lowercase, hexadecimal_uppercase, lowercase, uppercase, no_look_alikes, no_look_alikes_safe, alphanumeric, default, };
};

/// The default length for nanoids.
pub const default_id_len = 21;

/// The mask for the default alphabet length.
pub const default_mask = computeMask(alphabets.default.len);

/// This should be enough memory for an rng step buffer when generating an id of default length regardless of alphabet length.
/// It can be used for allocating your rng step buffer if you know the length of your id is `<= default_id_len`.
pub const rng_step_buffer_len_sufficient_for_default_length_ids = computeSufficientRngStepBufferLengthFor(default_id_len);

/// The maximum length of the alphabet accepted by the nanoid algorithm.
pub const max_alphabet_len: u8 = std.math.maxInt(u8);

/// Computes the mask necessary for the nanoid algorithm given an alphabet length.
/// The mask is used to transform a random byte into an index into an array of length `alphabet_len`.
///
/// Parameters:
/// - `alphabet_len`: the length of the alphabet used. The alphabet length must be in the range `(0, max_alphabet_len]`.
pub fn computeMask(alphabet_len: u8) u8
{
    std.debug.assert(alphabet_len > 0);

    const clz: u5 = @clz(@as(u31, (alphabet_len - 1) | 1));
    const mask = (@as(u32, 2) << (31 - clz)) - 1;
    const result: u8 = @truncate(mask);
    return result;
}

/// Computes the length necessary for a buffer which can hold the random byte in a step of a the nanoid generation algorithm given a 
/// certain alphabet length.
///
/// Parameters:
/// - `id_len`: the length of the id you will generate. Can be any value.
///
/// - `alphabet_len`: the length of the alphabet used. The alphabet length must be in the range `(0, max_alphabet_len]`.
pub fn computeRngStepBufferLength(id_len: usize, alphabet_len: u8) usize
{
    // @Note: 
    // Original dev notes regarding this algorithm. 
    // Source: https://github.com/ai/nanoid/blob/0454333dee4612d2c2e163d271af6cc3ce1e5aa4/index.js#L45
    // 
    // "Next, a step determines how many random bytes to generate.
    // The number of random bytes gets decided upon the ID length, mask,
    // alphabet length, and magic number 1.6 (using 1.6 peaks at performance
    // according to benchmarks)."

    const id_len_f: f64 = @as(f64, @floatFromInt(id_len));
    const mask_f: f64 = @as(f64, @floatFromInt(computeMask(alphabet_len)));
    const alphabet_len_f: f64 = @as(f64, @floatFromInt(alphabet_len));
    const step_buffer_len: f64 = @ceil(1.6 * mask_f * id_len_f / alphabet_len_f);
    const result = @as(usize, @intFromFloat(step_buffer_len));
    
    return result;
}

/// This function computes the biggest possible rng step buffer length necessary 
/// to compute an id with a max length of `max_id_len` regardless of the alphabet length.
/// 
/// Parameters:
/// - `max_id_len`: The biggest id length for which the step buffer length needs to be sufficient.
pub fn computeSufficientRngStepBufferLengthFor(max_id_len: usize) usize
{
    @setEvalBranchQuota(2500);
    var max_step_buffer_len: usize = 0;
    var i: u9 = 1;
    while (i <= max_alphabet_len) : (i += 1)
    {
        const alphabet_len: u8 = @truncate(i);
        const step_buffer_len = computeRngStepBufferLength(max_id_len, alphabet_len);

        if (step_buffer_len > max_step_buffer_len)
        {
            max_step_buffer_len = step_buffer_len;
        }
    }

    return max_step_buffer_len;
}

/// Generates a nanoid inside `result_buffer` and returns it back to the caller.
///
/// Parameters:
/// - `rng`: a random number generator. 
///    Provide a secure one such as `std.Random.DefaultCsprng` and seed it properly if you have security concerns. 
///    See `Regarding RNGs` in `readme.md` for more information.
///
/// - `alphabet`: an array of the bytes that will be used in the id, its length must be in the range `(0, max_alphabet_len]`.
///    Consider the options from `nanoid.alphabets`.
///
/// - `result_buffer`: is an output buffer that will be filled *completely* with random bytes from `alphabet`, thus generating an id of 
///    length `result_buffer.len`. This buffer will be returned at the end of the function.
///
/// - `step_buffer`: The buffer will be filled with random bytes using `rng.bytes()`.
///    Must be at least `computeRngStepBufferLength(computeMask(@truncate(alphabet.len)), result_buffer.len, alphabet.len)` bytes.
pub fn generateEx(rng: std.Random, alphabet: []const u8, result_buffer: []u8, step_buffer: []u8) []u8
{
    std.debug.assert(alphabet.len > 0 and alphabet.len <= max_alphabet_len);        

    const alphabet_len: u8 = @truncate(alphabet.len);
    const mask = computeMask(alphabet_len);
    const necessary_step_buffer_len = computeRngStepBufferLength(result_buffer.len, alphabet_len);
    const actual_step_buffer = step_buffer[0..necessary_step_buffer_len];

    var result_iter: usize = 0;
    while (true)
    {
        rng.bytes(actual_step_buffer);

        for (actual_step_buffer) |it|
        {
            const alphabet_index = it & mask;
            
            if (alphabet_index >= alphabet_len)
            {
                continue;
            }

            result_buffer[result_iter] = alphabet[alphabet_index];

            if (result_iter == result_buffer.len - 1)
            {
                return result_buffer;
            }
            else
            {
                result_iter += 1;
            }
        }
    }
}

/// Generates a nanoid inside `result_buffer` and returns it back to the caller.
///
/// This function will use `rng.int` instead of `rng.bytes` thus avoiding the need for a step buffer.
/// Depending on your choice of rng this can be useful, since you avoid the need for a step buffer, 
/// but repeated calls to `rng.int` might be slower than a single call `rng.bytes`.
///
/// Parameters:
/// - `rng`: a random number generator. 
///    Provide a secure one such as `std.Random.DefaultCsprng` and seed it properly if you have security concerns. 
///    See `Regarding RNGs` in `readme.md` for more information.
///
/// - `alphabet`: an array of the bytes that will be used in the id, its length must be in the range `(0, max_alphabet_len]`.
///    Consider the options from `nanoid.alphabets`.
///
/// - `result_buffer` is an output buffer that will be filled *completely* with random bytes from `alphabet`, thus generating an id of 
///    length `result_buffer.len`. This buffer will be returned at the end of the function.
pub fn generateExWithIterativeRng(rng: std.Random, alphabet: []const u8, result_buffer: []u8) []u8
{
    std.debug.assert(result_buffer.len > 0);
    std.debug.assert(alphabet.len > 0 and alphabet.len <= max_alphabet_len);

    const alphabet_len: u8 = @truncate(alphabet.len);
    const mask = computeMask(alphabet_len);

    var result_iter: usize = 0;
    while (true)
    {
        const random_byte = rng.int(u8);

        const alphabet_index = random_byte & mask;

        if (alphabet_index >= alphabet_len)
        {
            continue;
        }
        
        result_buffer[result_iter] = alphabet[alphabet_index];

        if (result_iter == result_buffer.len - 1)
        {
            return result_buffer;
        }
        else
        {
            result_iter += 1;
        }
    }

    return result_buffer;
}

/// Generates a nanoid using the provided alphabet.
///
/// Parameters:
///
/// - `rng`: a random number generator. 
///    Provide a secure one such as `std.Random.DefaultCsprng` and seed it properly if you have security concerns. 
///    See `Regarding RNGs` in `README.md` for more information.
///
/// - `alphabet`: an array of the bytes that will be used in the id, its length must be in the range `(0, max_alphabet_len]`.
pub fn generateWithAlphabet(rng: std.Random, alphabet: []const u8) [default_id_len]u8
{
    var nanoid: [default_id_len]u8 = undefined;
    var step_buffer: [rng_step_buffer_len_sufficient_for_default_length_ids]u8 = undefined;
    _ = generateEx(rng, alphabet, &nanoid, &step_buffer);
    return nanoid;
}

/// Generates a nanoid using the default alphabet.
///
/// Parameters:
///
/// - `rng`: a random number generator. 
///    Provide a secure one such as `std.Random.DefaultCsprng` and seed it properly if you have security concerns. 
///    See `Regarding RNGs` in `README.md` for more information.
pub fn generate(rng: std.Random) [default_id_len]u8
{
    const result = generateWithAlphabet(rng, alphabets.default);
    return result;
}

/// Non public utility functions used mostly in unit tests.
const internal_utils = struct 
{
    fn makeDefaultCsprng() std.Random.DefaultCsprng 
    {
        // Generate seed
        var seed: [std.Random.DefaultCsprng.secret_seed_length]u8 = undefined;
        std.crypto.random.bytes(&seed);

        // Initialize the rng and allocator
        const rng = std.Random.DefaultCsprng.init(seed);
        return rng;
    }

    fn makeDefaultPrngWithConstantSeed() std.Random.DefaultPrng
    {
        const rng = std.Random.DefaultPrng.init(0);
        return rng;
    }

    fn makeDefaultCsprngWithConstantSeed() std.Random.DefaultCsprng
    {
        // Generate seed
        const seed: [std.Random.DefaultCsprng.secret_seed_length]u8 = undefined;
        for (seed) |*it| it.* = 'a';

        // Initialize the rng and allocator
        const rng = std.Random.DefaultCsprng.init(seed);
        return rng;
    }

    /// Taken from https://github.com/codeyu/nanoid-net/blob/445f4d363e0079e151ea414dab1a9f9961679e7e/test/Nanoid.Test/NanoidTest.cs#L145
    fn toBeCloseTo(actual: f64, expected: f64, precision: f64) bool
    {
        const pass = @abs(expected - actual) < std.math.pow(f64, 10, -precision) / 2;
        return pass;
    }

    /// Checks if all elements in `array` are present in `includedIn`.
    fn allIn(comptime T: type, array: []const T, includedIn: []const T) bool 
    {
        for (array) |it|
        {
            if (std.mem.indexOfScalar(u8, includedIn, it) == null) 
            {
                return false;
            }
        }

        return true;
    }
};

test "calling computeMask with all acceptable input"
{
    var i: u9 = 1;
    while (i <= max_alphabet_len) : (i += 1) 
    {
        const alphabet_len: u8 = @truncate(i);
        const mask = computeMask(alphabet_len);
        try std.testing.expect(mask > 0);
    }
}

test "calling computeRngStepBufferLength with all acceptable alphabet sizes and default id length"
{
    var i: u9 = 1;
    while (i <= max_alphabet_len) : (i += 1)
    {
        const alphabet_len: u8 = @truncate(i);
        const rng_step_size = computeRngStepBufferLength(default_id_len, alphabet_len);
        try std.testing.expect(rng_step_size > 0);
    }
}

test "generating an id with default settings"
{
    // Init rng
    var rng = internal_utils.makeDefaultCsprng();
    
    // Generate a nanoid
    const result = generate(rng.random());
    try std.testing.expect(internal_utils.allIn(u8, &result, alphabets.default));
}

test "generating an id with a custom length"
{
    // Init rng
    var rng = internal_utils.makeDefaultCsprng();
    
    // Generate a nanoid
    const custom_id_len = 10;
    const rng_step_size = comptime computeRngStepBufferLength(custom_id_len, alphabets.default.len);
    
    var result_buffer: [custom_id_len]u8 = undefined;
    var step_buffer: [rng_step_size]u8 = undefined;

    const result = generateEx(rng.random(), alphabets.default, &result_buffer, &step_buffer);

    try std.testing.expect(result.len == custom_id_len);
}

test "generating an id with a custom alphabet"
{
    // Initialize the rng
    var rng = internal_utils.makeDefaultCsprng();
    
    // Generate a nanoid
    const custom_alphabet = "1234abcd";
    const result = generateWithAlphabet(rng.random(), custom_alphabet);

    try std.testing.expect(internal_utils.allIn(u8, &result, custom_alphabet));
}

test "generating an id for all alphabets"
{
    var rng = internal_utils.makeDefaultCsprng();
    
    for (alphabets.all) |alphabet|
    {
        const result = generateWithAlphabet(rng.random(), alphabet);

        try std.testing.expect(internal_utils.allIn(u8, &result, alphabet));
    }
}

test "generating an id with a custom alphabet and length"
{
    // Initialize the rng
    var rng = internal_utils.makeDefaultCsprng();
    
    // Generate a nanoid
    const custom_alphabet = "1234abcd";
    const custom_id_len = 7;
    var result_buffer: [custom_id_len]u8 = undefined;
    var step_buffer: [computeSufficientRngStepBufferLengthFor(custom_id_len)]u8 = undefined;
    const result = generateEx(rng.random(), custom_alphabet, &result_buffer, &step_buffer);

    try std.testing.expect(result.len == custom_id_len);
    
    for (result) |it|
    {
        try std.testing.expect(std.mem.indexOfScalar(u8, custom_alphabet, it) != null);
    }
}

test "generating an id with a single letter alphabet"
{
    // Initialize the rng and allocator
    var rng = internal_utils.makeDefaultCsprng();
    
    // Generate a nanoid
    const custom_alphabet = "a";
    const custom_id_len = 5;
    var result_buffer: [custom_id_len]u8 = undefined;
    var step_buffer: [computeSufficientRngStepBufferLengthFor(custom_id_len)]u8 = undefined;
    const result = generateEx(rng.random(), custom_alphabet, &result_buffer, &step_buffer);

    try std.testing.expect(std.mem.eql(u8, "aaaaa", result));
}

test "flat distribution of generated ids"
{
    // Initialize the rng and allocator
    var rng = internal_utils.makeDefaultCsprng();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    // Generate a nanoid
    const number_of_ids_to_generate = 100 * 1000;

    var characters_counts = std.AutoArrayHashMap(u8, usize).init(gpa.allocator());
    defer characters_counts.deinit();
 
    // Generate ids
    var i: usize = 0;
    while (i < number_of_ids_to_generate) : (i += 1)
    {
        const id = generate(rng.random());

        // Count the occurence of every character across all generated ids
        for (id) |char|
        {
            const char_count = characters_counts.getPtr(char);
            if (char_count) |c|
            {
                c.* += 1;
            }
            else 
            {
                try characters_counts.put(char, 0);
            }
        }
    }

    for (characters_counts.values()) |value|
    {
        const value_f: f64 = @as(f64, @floatFromInt(value));
        const alphabet_len_f: f64 = alphabets.default.len;
        const count_f: f64 = number_of_ids_to_generate;
        const id_len_f: f64 = default_id_len;
        const distribution = value_f * alphabet_len_f / (count_f * id_len_f);
        try std.testing.expect(internal_utils.toBeCloseTo(distribution, 1, 1));
    }
}

test "flat distribution of generated ids with the iterative method"
{
    // Initialize the rng and allocator
    var rng = internal_utils.makeDefaultCsprng();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    // Generate a nanoid
    const number_of_ids_to_generate = 100 * 1000;

    var characters_counts = std.AutoArrayHashMap(u8, usize).init(gpa.allocator());
    defer characters_counts.deinit();
 
    // Generate ids
    var i: usize = 0;
    while (i < number_of_ids_to_generate) : (i += 1)
    {
        var id_buffer: [default_id_len]u8 = undefined;
        const id = generateExWithIterativeRng(rng.random(), alphabets.default, &id_buffer);

        // Count the occurence of every character across all generated ids
        for (id) |char|
        {
            const char_count = characters_counts.getPtr(char);
            if (char_count) |c|
            {
                c.* += 1;
            }
            else 
            {
                try characters_counts.put(char, 0);
            }
        }
    }

    for (characters_counts.values()) |value|
    {
        const value_f: f64 = @as(f64, @floatFromInt(value));
        const alphabet_len_f: f64 = alphabets.default.len;
        const count_f: f64 = number_of_ids_to_generate;
        const id_len_f: f64 = default_id_len;
        const distribution = value_f * alphabet_len_f / (count_f * id_len_f);
        try std.testing.expect(internal_utils.toBeCloseTo(distribution, 1, 1));
    }
}