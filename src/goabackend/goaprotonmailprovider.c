/* goaprotonmailprovider.c — GOA provider for Proton Mail
 *
 * Copyright 2024 Proton AG
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * Implements GoaProvider so that Geary/Evolution pick up the
 * Proton Mail Bridge IMAP/SMTP endpoints automatically.
 *
 * Proton Mail Bridge listens on localhost:
 *   IMAP: 127.0.0.1:1143
 *   SMTP: 127.0.0.1:1025
 */

#include "goaprotonmailprovider.h"
#include "goaprotondriveprovider.h"
#include "goaprotoncalendarprovider.h"

#include <glib/gi18n.h>
#include <gio/gio.h>

#define PROTON_MAIL_PROVIDER_TYPE "proton_mail"

#define PROTON_IMAP_HOST "127.0.0.1"
#define PROTON_IMAP_PORT 1143
#define PROTON_SMTP_HOST "127.0.0.1"
#define PROTON_SMTP_PORT 1025

struct _GoaProtonMailProvider
{
  GoaProvider parent_instance;
};

G_DEFINE_DYNAMIC_TYPE (GoaProtonMailProvider,
                       goa_proton_mail_provider,
                       GOA_TYPE_PROVIDER)

static const gchar *
goa_proton_mail_provider_get_provider_type (GoaProvider *provider)
{
  return PROTON_MAIL_PROVIDER_TYPE;
}

static gchar *
goa_proton_mail_provider_get_provider_name (GoaProvider *provider,
                                            GoaObject   *object)
{
  return g_strdup (_("Proton Mail"));
}

static GIcon *
goa_proton_mail_provider_get_provider_icon (GoaProvider *provider,
                                            GoaObject   *object)
{
  return g_themed_icon_new_with_default_fallbacks ("proton-mail-symbolic");
}

static GoaProviderFeatures
goa_proton_mail_provider_get_provider_features (GoaProvider *provider)
{
  return GOA_PROVIDER_FEATURE_MAIL;
}

static GoaObject *
goa_proton_mail_provider_add_account (GoaProvider  *provider,
                                      GoaClient    *client,
                                      GtkDialog    *dialog,
                                      GtkBox       *vbox,
                                      GError      **error)
{
  g_set_error_literal (error,
                       GOA_ERROR,
                       GOA_ERROR_NOT_SUPPORTED,
                       "Proton Mail account setup is not yet implemented");
  return NULL;
}

static gboolean
goa_proton_mail_provider_build_object (GoaProvider         *provider,
                                       GoaObjectSkeleton   *object,
                                       GKeyFile            *key_file,
                                       const gchar         *group,
                                       GDBusConnection     *connection,
                                       gboolean             just_added,
                                       GError             **error)
{
  GoaMail *mail;

  mail = GOA_MAIL (goa_mail_skeleton_new ());

  g_object_set (mail,
                "imap-supported",         TRUE,
                "imap-host",              PROTON_IMAP_HOST,
                "imap-port",              (guint32) PROTON_IMAP_PORT,
                "imap-tls-type",          GOA_TLS_TYPE_NONE,
                "imap-accept-ssl-errors", FALSE,
                "imap-user-name",         "",
                "smtp-supported",         TRUE,
                "smtp-host",              PROTON_SMTP_HOST,
                "smtp-port",              (guint32) PROTON_SMTP_PORT,
                "smtp-tls-type",          GOA_TLS_TYPE_NONE,
                "smtp-accept-ssl-errors", FALSE,
                "smtp-use-auth",          FALSE,
                "smtp-user-name",         "",
                NULL);

  goa_object_skeleton_set_mail (object, mail);
  g_object_unref (mail);

  return TRUE;
}

static guint
goa_proton_mail_provider_get_credentials_generation (GoaProvider *provider)
{
  return 1;
}

static void
goa_proton_mail_provider_init (GoaProtonMailProvider *self)
{
}

static void
goa_proton_mail_provider_class_init (GoaProtonMailProviderClass *klass)
{
  GoaProviderClass *provider_class = GOA_PROVIDER_CLASS (klass);

  provider_class->get_provider_type          = goa_proton_mail_provider_get_provider_type;
  provider_class->get_provider_name          = goa_proton_mail_provider_get_provider_name;
  provider_class->get_provider_icon          = goa_proton_mail_provider_get_provider_icon;
  provider_class->get_provider_features      = goa_proton_mail_provider_get_provider_features;
  provider_class->add_account                = goa_proton_mail_provider_add_account;
  provider_class->build_object               = goa_proton_mail_provider_build_object;
  provider_class->get_credentials_generation = goa_proton_mail_provider_get_credentials_generation;
}

static void
goa_proton_mail_provider_class_finalize (GoaProtonMailProviderClass *klass)
{
}

/* GIO module entry points — registers all three Proton providers */

void
g_io_module_load (GIOModule *module)
{
  g_type_module_use (G_TYPE_MODULE (module));

  goa_proton_mail_provider_register_type (G_TYPE_MODULE (module));
  goa_proton_drive_provider_register_type (G_TYPE_MODULE (module));
  goa_proton_calendar_provider_register_type (G_TYPE_MODULE (module));

  g_io_extension_point_implement (GOA_PROVIDER_EXTENSION_POINT_NAME,
                                  GOA_TYPE_PROTON_MAIL_PROVIDER,
                                  "proton_mail",
                                  0);
  g_io_extension_point_implement (GOA_PROVIDER_EXTENSION_POINT_NAME,
                                  GOA_TYPE_PROTON_DRIVE_PROVIDER,
                                  "proton_drive",
                                  0);
  g_io_extension_point_implement (GOA_PROVIDER_EXTENSION_POINT_NAME,
                                  GOA_TYPE_PROTON_CALENDAR_PROVIDER,
                                  "proton_calendar",
                                  0);
}

void
g_io_module_unload (GIOModule *module)
{
}
