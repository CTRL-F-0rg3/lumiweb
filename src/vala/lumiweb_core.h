#ifndef LUMIWEB_CORE_H
#define LUMIWEB_CORE_H
#include <glib.h>
void lw_init(void);
void lw_add_history(const char* url, const char* title);
const char* lw_get_history_html(void);
void lw_free_string(const char* s);
const char* lw_plugin_js(const char* path, const char* current_url);
const char* lw_plugin_css(const char* path, const char* current_url);
void lw_calendar_add(const char* date, const char* title, const char* description);
const char* lw_calendar_list(void);
void lw_calendar_delete(long long id);
void lw_todo_add(const char* title);
void lw_todo_toggle(long long id);
void lw_todo_delete(long long id);
const char* lw_todo_list(void);
void lw_notes_save(const char* content);
const char* lw_notes_load(void);
void lw_bookmark_add(const char* url, const char* title);
void lw_bookmark_delete(long long id);
const char* lw_bookmark_list(void);
void lw_workspace_add(const char* name, const char* urls_json);
void lw_workspace_delete(long long id);
const char* lw_workspace_list(void);
void lw_download_log(const char* url, const char* path);
const char* lw_download_list(void);
const char* lw_plugin_notify(const char* path, const char* current_url);
#endif
