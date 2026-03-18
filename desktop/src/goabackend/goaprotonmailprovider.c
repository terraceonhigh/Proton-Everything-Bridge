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
#include "goaprotonauth.h"
#include "goaproviderdialog.h"

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

G_DEFINE_TYPE_WITH_CODE (GoaProtonMailProvider,
                        goa_proton_mail_provider,
                        GOA_TYPE_PROVIDER,
                        goa_provider_ensure_extension_points_registered ();
                        g_io_extension_point_implement (GOA_PROVIDER_EXTENSION_POINT_NAME,
                                                       g_define_type_id,
                                                       PROTON_MAIL_PROVIDER_TYPE,
                                                       0))

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
  const gchar *names[] = { "proton-mail-symbolic", "mail-symbolic", NULL };
  return G_ICON (g_themed_icon_new_from_names ((gchar **) names, -1));
}

static GoaProviderGroup
goa_proton_mail_provider_get_provider_group (GoaProvider *provider)
{
  return GOA_PROVIDER_GROUP_BRANDED;
}

static GoaProviderFeatures
goa_proton_mail_provider_get_provider_features (GoaProvider *provider)
{
  return GOA_PROVIDER_FEATURE_MAIL;
}

/* ---- add_account (async) ---- */

typedef struct
{
  GoaProviderDialog *dialog;
  GoaClient         *client;
  GtkWidget         *email_entry;
} AddMailAccountData;

static void
add_mail_account_data_free (gpointer data)
{
  AddMailAccountData *d = data;
  g_clear_object (&d->client);
  g_free (d);
}

static void
add_mail_account_credentials_cb (GoaManager   *manager,
                                 GAsyncResult *res,
                                 gpointer      user_data)
{
  g_autoptr(GTask) task = G_TASK (g_steal_pointer (&user_data));
  AddMailAccountData *data = g_task_get_task_data (task);
  g_autofree gchar *object_path = NULL;
  GError *error = NULL;

  if (!goa_manager_call_add_account_finish (manager, &object_path, res, &error))
    {
      goa_provider_task_return_error (task, error);
      return;
    }

  GoaObject *object = GOA_OBJECT (
    g_dbus_object_manager_get_object (
      goa_client_get_object_manager (data->client), object_path));
  goa_provider_task_return_account (task, object);
}

static void
add_mail_account_action_cb (GoaProviderDialog *dialog,
                            GParamSpec        *pspec,
                            GTask             *task)
{
  GoaProvider *provider = g_task_get_source_object (task);
  AddMailAccountData *data = g_task_get_task_data (task);
  GCancellable *cancellable = g_task_get_cancellable (task);
  const gchar *email;
  GVariantBuilder credentials;
  GVariantBuilder details;

  if (goa_provider_dialog_get_state (data->dialog) != GOA_DIALOG_BUSY)
    return;

  email = gtk_editable_get_text (GTK_EDITABLE (data->email_entry));
  if (email == NULL || *email == '\0')
    {
      GError *error = g_error_new (GOA_ERROR, GOA_ERROR_FAILED,
                                   _("Please enter an email address"));
      goa_provider_dialog_report_error (data->dialog, error);
      g_error_free (error);
      return;
    }

  /* Verify bridge is running */
  if (!goa_proton_bridge_is_running (PROTON_IMAP_PORT))
    {
      GError *error = g_error_new (GOA_ERROR, GOA_ERROR_FAILED,
                                   _("Proton Mail Bridge is not running on port %d.\n"
                                     "Please start Proton Mail Bridge and sign in first."),
                                   PROTON_IMAP_PORT);
      goa_provider_dialog_report_error (data->dialog, error);
      g_error_free (error);
      return;
    }

  /* Persist the account */
  g_variant_builder_init (&credentials, G_VARIANT_TYPE_VARDICT);

  g_variant_builder_init (&details, G_VARIANT_TYPE ("a{ss}"));
  g_variant_builder_add (&details, "{ss}", "Enabled", "true");
  g_variant_builder_add (&details, "{ss}", "EmailAddress", email);
  g_variant_builder_add (&details, "{ss}", "ImapHost", PROTON_IMAP_HOST);
  g_variant_builder_add (&details, "{ss}", "ImapPort", G_STRINGIFY (PROTON_IMAP_PORT));
  g_variant_builder_add (&details, "{ss}", "SmtpHost", PROTON_SMTP_HOST);
  g_variant_builder_add (&details, "{ss}", "SmtpPort", G_STRINGIFY (PROTON_SMTP_PORT));
  g_variant_builder_add (&details, "{ss}", "MailEnabled", "true");

  goa_manager_call_add_account (
    goa_client_get_manager (data->client),
    goa_provider_get_provider_type (provider),
    email,
    email,
    g_variant_builder_end (&credentials),
    g_variant_builder_end (&details),
    cancellable,
    (GAsyncReadyCallback) add_mail_account_credentials_cb,
    g_object_ref (task));
}

static void
goa_proton_mail_provider_add_account (GoaProvider         *provider,
                                      GoaClient           *client,
                                      GtkWindow           *parent,
                                      GCancellable        *cancellable,
                                      GAsyncReadyCallback  callback,
                                      gpointer             user_data)
{
  AddMailAccountData *data;
  g_autoptr(GTask) task = NULL;
  GtkWidget *group;

  data = g_new0 (AddMailAccountData, 1);
  data->dialog = goa_provider_dialog_new (provider, client, parent);
  data->client = g_object_ref (client);

  task = g_task_new (provider, cancellable, callback, user_data);
  g_task_set_check_cancellable (task, FALSE);
  g_task_set_source_tag (task, goa_proton_mail_provider_add_account);
  g_task_set_task_data (task, data, add_mail_account_data_free);
  goa_provider_task_bind_window (task, GTK_WINDOW (data->dialog));

  goa_provider_dialog_add_page (data->dialog,
                                _("Proton Mail"),
                                _("Proton Mail Bridge must be running and logged in."));
  group = goa_provider_dialog_add_group (data->dialog, NULL);
  data->email_entry = goa_provider_dialog_add_entry (data->dialog, group, _("_Email"));
  goa_provider_dialog_add_description (data->dialog, NULL,
    _("Enter the email address you use with Proton Mail Bridge."));

  g_signal_connect_object (data->dialog,
                           "notify::state",
                           G_CALLBACK (add_mail_account_action_cb),
                           task,
                           0);
  gtk_widget_grab_focus (data->email_entry);
  gtk_window_present (GTK_WINDOW (data->dialog));
}

/* ---- refresh_account (async) ---- */

static void
goa_proton_mail_provider_refresh_account (GoaProvider         *provider,
                                          GoaClient           *client,
                                          GoaObject           *object,
                                          GtkWindow           *parent,
                                          GCancellable        *cancellable,
                                          GAsyncReadyCallback  callback,
                                          gpointer             user_data)
{
  g_autoptr(GTask) task = NULL;

  task = g_task_new (provider, cancellable, callback, user_data);
  g_task_set_source_tag (task, goa_proton_mail_provider_refresh_account);

  if (!goa_proton_bridge_is_running (PROTON_IMAP_PORT))
    {
      g_task_return_new_error (task, GOA_ERROR, GOA_ERROR_FAILED,
                               _("Proton Mail Bridge is not running.\n"
                                 "Please start Proton Mail Bridge and try again."));
      return;
    }

  g_task_return_boolean (task, TRUE);
}

/* ---- ensure_credentials_sync ---- */

static gboolean
goa_proton_mail_provider_ensure_credentials_sync (GoaProvider   *provider,
                                                   GoaObject     *object,
                                                   gint          *out_expires_in,
                                                   GCancellable  *cancellable,
                                                   GError       **error)
{
  if (!goa_proton_bridge_is_running (PROTON_IMAP_PORT))
    {
      g_set_error (error, GOA_ERROR, GOA_ERROR_FAILED,
                   _("Proton Mail Bridge is not reachable on port %d"),
                   PROTON_IMAP_PORT);
      return FALSE;
    }

  if (out_expires_in != NULL)
    *out_expires_in = 0;

  return TRUE;
}

/* ---- build_object ---- */

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

  /* Chain up to parent to set base account properties */
  if (!GOA_PROVIDER_CLASS (goa_proton_mail_provider_parent_class)->build_object (
        provider, object, key_file, group, connection, just_added, error))
    return FALSE;

  mail = goa_object_get_mail (GOA_OBJECT (object));
  if (mail == NULL)
    {
      mail = GOA_MAIL (goa_mail_skeleton_new ());
      g_object_set (mail,
                    "imap-supported",         TRUE,
                    "imap-host",              PROTON_IMAP_HOST,
                    "imap-use-tls",           FALSE,
                    "imap-accept-ssl-errors", FALSE,
                    "imap-user-name",         "",
                    "smtp-supported",         TRUE,
                    "smtp-host",              PROTON_SMTP_HOST,
                    "smtp-use-tls",           FALSE,
                    "smtp-accept-ssl-errors", FALSE,
                    "smtp-use-auth",          FALSE,
                    "smtp-user-name",         "",
                    NULL);
      goa_object_skeleton_set_mail (object, mail);
    }
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
  provider_class->get_provider_group         = goa_proton_mail_provider_get_provider_group;
  provider_class->get_provider_icon          = goa_proton_mail_provider_get_provider_icon;
  provider_class->get_provider_features      = goa_proton_mail_provider_get_provider_features;
  provider_class->add_account                = goa_proton_mail_provider_add_account;
  provider_class->refresh_account            = goa_proton_mail_provider_refresh_account;
  provider_class->ensure_credentials_sync    = goa_proton_mail_provider_ensure_credentials_sync;
  provider_class->build_object               = goa_proton_mail_provider_build_object;
  provider_class->get_credentials_generation = goa_proton_mail_provider_get_credentials_generation;
}

/* GIO module entry points — registers all three Proton providers */

void
g_io_module_load (GIOModule *module)
{
  /* Ensure each type is registered — this triggers the
   * G_DEFINE_TYPE_WITH_CODE blocks which implement the extension points */
  g_type_ensure (goa_proton_mail_provider_get_type ());
  g_type_ensure (goa_proton_drive_provider_get_type ());
  g_type_ensure (goa_proton_calendar_provider_get_type ());
}

void
g_io_module_unload (GIOModule *module)
{
}

G_MODULE_EXPORT gchar **
g_io_module_query (void)
{
  gchar *eps[] = { GOA_PROVIDER_EXTENSION_POINT_NAME, NULL };
  return g_strdupv (eps);
}
