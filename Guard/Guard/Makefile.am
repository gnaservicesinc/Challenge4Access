bin_PROGRAMS = Guard
Guard_SOURCES = \
  main.c \
  guard_main.c \
  error.c \
  change_to_user.c \
  c4a_types.c \
  c4a_store.c \
  detection.c \
  tasks.c \
  guard_tick.c \
  $(top_srcdir)/sqlite-amalgamation-3500400/sqlite3.c
Guard_CPPFLAGS = -I$(srcdir) -I$(top_srcdir)/sqlite-amalgamation-3500400
Guard_LDADD = -lpthread
