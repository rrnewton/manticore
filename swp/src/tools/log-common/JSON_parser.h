/* JSON_parser.h
 *
 * COPYRIGHT (c) 2008 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *
 * This code is adapted from the JSON parser at
 *
 *	http://fara.cs.uni-potsdam.de/~jsg/json_parser/
 */

#ifndef JSON_PARSER_H
#define JSON_PARSER_H


#include <stddef.h>
/* Determine the integer type use to parse non-floating point numbers */
#if __STDC_VERSION__ >= 199901L || HAVE_LONG_LONG == 1
typedef long long JSON_int_t;
#define JSON_PARSER_INTEGER_SSCANF_TOKEN "%lld"
#define JSON_PARSER_INTEGER_SPRINTF_TOKEN "%lld"
#else 
typedef long JSON_int_t;
#define JSON_PARSER_INTEGER_SSCANF_TOKEN "%ld"
#define JSON_PARSER_INTEGER_SPRINTF_TOKEN "%ld"
#endif

typedef enum 
{
    JSON_T_NONE = 0,
    JSON_T_ARRAY_BEGIN,
    JSON_T_ARRAY_END,
    JSON_T_OBJECT_BEGIN,
    JSON_T_OBJECT_END,
    JSON_T_INTEGER,
    JSON_T_FLOAT,
    JSON_T_NULL,
    JSON_T_TRUE,
    JSON_T_FALSE,
    JSON_T_STRING,
    JSON_T_KEY,
    JSON_T_MAX
} JSON_type;

typedef struct JSON_value_struct {
    union {
        JSON_int_t integer_value;
        
        long double float_value;
        
        struct {
            const char* value;
            size_t length;
        } str;
    } vu;
} JSON_value;

/*! \brief JSON parser callback 

    \param ctx The pointer passed to new_JSON_parser.
    \param type An element of JSON_type but not JSON_T_NONE.    
    \param value A representation of the parsed value. This parameter is NULL for
        JSON_T_ARRAY_BEGIN, JSON_T_ARRAY_END, JSON_T_OBJECT_BEGIN, JSON_T_OBJECT_END,
        JSON_T_NULL, JSON_T_TRUE, and SON_T_FALSE. String values are always returned
        as zero-terminated C strings.

    \return Non-zero if parsing should continue, else zero.
*/    
typedef int (*JSON_parser_callback)(void* ctx, int type, const struct JSON_value_struct* value);


/*! \brief The structure used to configure a JSON parser object 
    
    \param depth If negative, the parser can parse arbitrary levels of JSON, otherwise
        the depth is the limit
    \param Pointer to a callback. This parameter may be NULL. In this case the input is merely checked for validity.
    \param Callback context. This parameter may be NULL.
    \param depth. Specifies the levels of nested JSON to allow. Negative numbers yield unlimited nesting.
    \param allowComments. To allow C style comments in JSON, set to non-zero.
    \param handleFloatsManually. To decode floating point numbers manually set this parameter to non-zero.
    
    \return The parser object.
*/
typedef struct JSON_config_struct {
    JSON_parser_callback     callback;
    void*                    callback_ctx;
    int                      depth;
    int                      allow_comments;
    int                      handle_floats_manually;
} JSON_config;


/*! \brief Initializes the JSON parser configuration structure to default values.

    The default configuration is
    - 127 levels of nested JSON (depends on JSON_PARSER_STACK_SIZE, see json_parser.c)
    - no parsing, just checking for JSON syntax
    - no comments

    \param config. Used to configure the parser.
*/
void init_JSON_config(JSON_config* config);

/*! \brief Create a JSON parser object 
    
    \param config. Used to configure the parser. Set to NULL to use the default configuration. 
        See init_JSON_config
    
    \return The parser object.
*/
extern struct JSON_parser_struct* new_JSON_parser(JSON_config* config);

/*! \brief Destroy a previously created JSON parser object. */
extern void delete_JSON_parser(struct JSON_parser_struct* jc);

/*! \brief Parse a character.

    \return Non-zero, if all characters passed to this function are part of are valid JSON.
*/
extern int JSON_parser_char(struct JSON_parser_struct* jc, int next_char);

/*! \brief Finalize parsing.

    Call this method once after all input characters have been consumed.
    
    \return Non-zero, if all parsed characters are valid JSON, zero otherwise.
*/
extern int JSON_parser_done(struct JSON_parser_struct* jc);

/*! \brief Determine if a given string is valid JSON white space 

    \return Non-zero if the string is valid, zero otherwise.
*/
extern int JSON_parser_is_legal_white_space_string(const char* s);
    

#endif /* JSON_PARSER_H */
