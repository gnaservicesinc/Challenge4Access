AC_INIT([Guard],[0.1])
AM_INIT_AUTOMAKE([foreign])
AC_PROG_CC
AC_CONFIG_SRCDIR([Guard/Guard/main.c])

AC_CONFIG_FILES([Makefile Guard/Guard/Makefile])
AC_CONFIG_MACRO_DIR([m4])
AM_SILENT_RULES([yes])
AC_SUBST([abs_srcdir], ["`cd $srcdir && pwd`"])
AC_SUBST([abs_builddir], ["`pwd`"])
if test "$abs_srcdir" = "$abs_builddir"; then
  canonicalized_srcdir=""
else
  canonicalized_srcdir="$srcdir/"
fi
AC_SUBST([canonicalized_srcdir])
AC_PROG_CC
AC_PROG_CPP
AC_PROG_INSTALL
AC_C_INLINE
AC_TYPE_SIZE_T
AC_CHECK_HEADERS([libintl.h stdlib.h string.h syslog.h unistd.h wchar.h sys/time.h])
AC_FUNC_FORK
AC_FUNC_MALLOC
AC_CHECK_FUNCS([memset strrchr pathconf realpath strerror])
AC_PATH_PROG(PKG_CONFIG, pkg-config)
AC_FUNC_MEMCMP
AC_CHECK_FUNCS(symlink readlink)
AC_CHECK_HEADERS(sys/utsname.h, [AC_CHECK_FUNCS(uname)], [])

AC_ARG_ENABLE([debug],
  AS_HELP_STRING([--enable-debug],
    [enable printing more debugging info])
)
AS_IF([test "x$enable_debug" = "xyes"], [
            AC_DEFINE([DEBUG_TOGGLE], [""],
            [Enable debug toggle])
])
AC_OUTPUT
