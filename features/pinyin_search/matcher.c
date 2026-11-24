/* Pinyin fallback for the build toolbar's native UTF-32 search. */
#include <stdint.h>

struct ToolbarString {
    union {
        uint32_t local[4];
        const uint32_t *heap;
    } storage;
    uint64_t size;
    uint64_t capacity;
};

extern unsigned char StockToolbarMatch(const struct ToolbarString *label,
                                       const struct ToolbarString *query);
extern const uint32_t PinyinDictionary[];

enum {
    FirstHan = 0x3400,
    LastHan = 0x9fff,
    MaxQuery = 63,
    MaxLabel = 256
};

static const uint32_t *characters(const struct ToolbarString *text)
{
    return text->capacity < 4 ? text->storage.local : text->storage.heap;
}

static uint32_t reading_offset(uint32_t point)
{
    return point >= FirstHan && point <= LastHan
        ? PinyinDictionary[point - FirstHan]
        : 0;
}

static unsigned char latin(uint32_t point)
{
    if (point >= 'A' && point <= 'Z')
        point += 'a' - 'A';
    if ((point >= 'a' && point <= 'z') || (point >= '0' && point <= '9'))
        return (unsigned char)point;
    if (point == 0xfc || point == 0xdc)
        return 'v';
    return 0;
}

static int separator(uint32_t point)
{
    return point == ' ' || point == '\t' || point == '\'' || point == '-' ||
           point == 0x2019 || point == 0x3000;
}

static int label_separator(uint32_t point)
{
    return separator(point) || point == '(' || point == ')' ||
           point == 0xff08 || point == 0xff09;
}

static unsigned normalize_query(const struct ToolbarString *query, unsigned char *normalized)
{
    const uint32_t *text = characters(query);
    unsigned length = 0;
    for (uint64_t index = 0; index < query->size; ++index) {
        uint32_t point = text[index];
        if (separator(point))
            continue;
        unsigned char letter = latin(point);
        if (!letter || length == MaxQuery)
            return 0;
        normalized[length++] = letter;
    }
    return length;
}

static int advance_reading(const unsigned char *reading, unsigned reading_length,
                           const unsigned char *query, unsigned query_length,
                           uint64_t sources, uint64_t *destinations)
{
    for (unsigned start = 0; sources; ++start, sources >>= 1) {
        if (!(sources & 1) || query[start] != reading[0])
            continue;
        unsigned matched = 1;
        while (matched < reading_length && start + matched < query_length &&
               query[start + matched] == reading[matched])
            ++matched;
        if (start + matched == query_length)
            return 1;
        if (matched == reading_length)
            *destinations |= UINT64_C(1) << (start + matched);
    }
    return 0;
}

static int pinyin_match(const struct ToolbarString *label, const struct ToolbarString *query)
{
    if (!query->size || query->size > MaxLabel || !label->size || label->size > MaxLabel)
        return 0;
    unsigned char normalized[MaxQuery];
    unsigned length = normalize_query(query, normalized);
    if (!length)
        return 0;

    const uint32_t *text = characters(label);
    uint64_t first_han = 0;
    while (first_han < label->size && !reading_offset(text[first_han]))
        ++first_han;
    if (first_han == label->size)
        return 0;

    uint64_t full = 0;
    uint64_t initials = 0;
    for (uint64_t index = 0; index < label->size; ++index) {
        uint32_t point = text[index];
        if (label_separator(point))
            continue;

        /* Each bit is a consumed query prefix. Start at any character boundary. */
        uint64_t previous_full = full | 1;
        uint64_t previous_initials = initials | 1;
        full = initials = 0;
        uint32_t offset = reading_offset(point);
        if (!offset) {
            unsigned char literal = latin(point);
            if (literal && (advance_reading(&literal, 1, normalized, length, previous_full, &full) ||
                            advance_reading(&literal, 1, normalized, length, previous_initials, &initials)))
                return 1;
            continue;
        }

        const unsigned char *reading = (const unsigned char *)PinyinDictionary + offset;
        while (*reading) {
            unsigned count = 1;
            while (reading[count])
                ++count;
            if (advance_reading(reading, count, normalized, length, previous_full, &full) ||
                advance_reading(reading, 1, normalized, length, previous_initials, &initials))
                return 1;
            reading += count + 1;
        }
    }
    return 0;
}

unsigned char PinyinToolbarMatch(const struct ToolbarString *label, const struct ToolbarString *query)
{
    return StockToolbarMatch(label, query) || pinyin_match(label, query);
}
