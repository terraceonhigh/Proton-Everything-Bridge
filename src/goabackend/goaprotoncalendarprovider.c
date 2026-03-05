/* goaprotoncalendarprovider.c — GOA provider for Proton Calendar
 *
 * Copyright 2024 Proton AG
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * Implements GoaProvider so that GNOME Calendar picks up the
 * Proton Calendar Bridge CalDAV endpoint automatically.
 *
 * Proton Calendar Bridge exposes CalDAV at:
 *   http://127.0.0.1:9842/caldav/
 */

#include "goaprotoncalendarprovider.h"

#include <glib/gi18n.h>
#include <gio/gio.h>

#define PROTON_CALENDAR_PROVIDER_TYPE "proton_calendar"
#define PROTON_CALDAV_URI             "http://127.0.0.1:9842/caldav/"

struct _GoaProtonCalendarProvider
{
  GoaProvider parent_instance;
};

G_DEFINE_DYNAMIC_TYPE (GoaProtonCalendarProvider,
                       goa_proton_calendar_provider,
                       GOA_TYPE_PROVIDER)

static const gchar *
goa_proton_calendar_provider_get_provider_type (GoaProvider *provider)
{
  return PROTON_CALENDAR_PROVIDER_TYPE;
}

static gchar *
goa_proton_calendar_provider_get_provider_name (GoaProvider *provider,
                                                GoaObject   *object)
{
  return g_strdup (_("Proton Calendar"));
}

static GIcon *
goa_proton_calendar_provider_get_provider_icon (GoaProvider *provider,
                                                GoaObject   *object)
{
  return g_themed_icon_new_with_default_fallbacks ("proton-calendar-symbolic");
}

static GoaProviderFeatures
goa_proton_calendar_provider_get_provider_features (GoaProvider *provider)
{
  return GOA_PROVIDER_FEATURE_CALENDAR;
}

static GoaObject *
goa_proton_calendar_provider_add_account (GoaProvider  *provider,
                                          GoaClient    *client,
                                          GtkDialog    *dialog,
                                          GtkBox       *vbox,
                                          GError      **error)
{
  g_set_error_literal (error,
                       GOA_ERROR,
                       GOA_ERROR_NOT_SUPPORTED,
                       "Proton Calendar account setup is not yet implemented");
  return NULL;
}

static gboolean
goa_proton_calendar_provider_build_object (GoaProvider         *provider,
                                           GoaObjectSkeleton   *object,
                                           GKeyFile            *key_file,
                                           const gchar         *group,
                                           GDBusConnection     *connection,
                                           gboolean             just_added,
                                           GError             **error)
{
  GoaCalendar *calendar;

  calendar = GOA_CALENDAR (goa_calendar_skeleton_new ());
  g_object_set (calendar,
                "uri", PROTON_CALDAV_URI,
                NULL);

  goa_object_skeleton_set_calendar (object, calendar);
  g_object_unref (calendar);

  return TRUE;
}

static guint
goa_proton_calendar_provider_get_credentials_generation (GoaProvider *provider)
{
  return 1;
}

static void
goa_proton_calendar_provider_init (GoaProtonCalendarProvider *self)
{
}

static void
goa_proton_calendar_provider_class_init (GoaProtonCalendarProviderClass *klass)
{
  GoaProviderClass *provider_class = GOA_PROVIDER_CLASS (klass);

  provider_class->get_provider_type          = goa_proton_calendar_provider_get_provider_type;
  provider_class->get_provider_name          = goa_proton_calendar_provider_get_provider_name;
  provider_class->get_provider_icon          = goa_proton_calendar_provider_get_provider_icon;
  provider_class->get_provider_features      = goa_proton_calendar_provider_get_provider_features;
  provider_class->add_account                = goa_proton_calendar_provider_add_account;
  provider_class->build_object               = goa_proton_calendar_provider_build_object;
  provider_class->get_credentials_generation = goa_proton_calendar_provider_get_credentials_generation;
}

static void
goa_proton_calendar_provider_class_finalize (GoaProtonCalendarProviderClass *klass)
{
}
