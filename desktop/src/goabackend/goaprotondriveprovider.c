/* goaprotondriveprovider.c — GOA provider for Proton Drive
 *
 * Copyright 2024 Proton AG
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * Implements GoaProvider so that gvfs-goa exposes the Proton Drive
 * rclone FUSE mount in the Nautilus sidebar.
 */

#include "goaprotondriveprovider.h"
#include "goaprotonauth.h"
#include "goaproviderdialog.h"

#include <glib/gi18n.h>
#include <gio/gio.h>

#define PROTON_DRIVE_PROVIDER_TYPE "proton_drive"
#define PROTON_DRIVE_URI           "file://%s/ProtonDrive"

struct _GoaProtonDriveProvider
{
  GoaProvider parent_instance;
};

G_DEFINE_TYPE_WITH_CODE (GoaProtonDriveProvider,
                        goa_proton_drive_provider,
                        GOA_TYPE_PROVIDER,
                        goa_provider_ensure_extension_points_registered ();
                        g_io_extension_point_implement (GOA_PROVIDER_EXTENSION_POINT_NAME,
                                                       g_define_type_id,
                                                       PROTON_DRIVE_PROVIDER_TYPE,
                                                       0))

static const gchar *
goa_proton_drive_provider_get_provider_type (GoaProvider *provider)
{
  return PROTON_DRIVE_PROVIDER_TYPE;
}

static gchar *
goa_proton_drive_provider_get_provider_name (GoaProvider *provider,
                                             GoaObject   *object)
{
  return g_strdup (_("Proton Drive"));
}

static GIcon *
goa_proton_drive_provider_get_provider_icon (GoaProvider *provider,
                                             GoaObject   *object)
{
  const gchar *names[] = { "proton-drive-symbolic", "folder-remote-symbolic", NULL };
  return G_ICON (g_themed_icon_new_from_names ((gchar **) names, -1));
}

static GoaProviderGroup
goa_proton_drive_provider_get_provider_group (GoaProvider *provider)
{
  return GOA_PROVIDER_GROUP_BRANDED;
}

static GoaProviderFeatures
goa_proton_drive_provider_get_provider_features (GoaProvider *provider)
{
  return GOA_PROVIDER_FEATURE_FILES;
}

/* ---- add_account (async) ---- */

typedef struct
{
  GoaProviderDialog *dialog;
  GoaClient         *client;
  GtkWidget         *email_entry;
} AddDriveAccountData;

static void
add_drive_account_data_free (gpointer data)
{
  AddDriveAccountData *d = data;
  g_clear_object (&d->client);
  g_free (d);
}

static void
add_drive_account_credentials_cb (GoaManager   *manager,
                                  GAsyncResult *res,
                                  gpointer      user_data)
{
  g_autoptr(GTask) task = G_TASK (g_steal_pointer (&user_data));
  AddDriveAccountData *data = g_task_get_task_data (task);
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
add_drive_account_action_cb (GoaProviderDialog *dialog,
                             GParamSpec        *pspec,
                             GTask             *task)
{
  GoaProvider *provider = g_task_get_source_object (task);
  AddDriveAccountData *data = g_task_get_task_data (task);
  GCancellable *cancellable = g_task_get_cancellable (task);
  const gchar *email;
  GVariantBuilder credentials;
  GVariantBuilder details;
  g_autofree gchar *uri = NULL;

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

  if (!goa_proton_rclone_available ())
    {
      GError *error = g_error_new (GOA_ERROR, GOA_ERROR_FAILED,
                                   _("rclone is not installed.\n"
                                     "Please install rclone and configure a \"proton:\" remote."));
      goa_provider_dialog_report_error (data->dialog, error);
      g_error_free (error);
      return;
    }

  uri = g_strdup_printf (PROTON_DRIVE_URI, g_get_home_dir ());

  g_variant_builder_init (&credentials, G_VARIANT_TYPE_VARDICT);

  g_variant_builder_init (&details, G_VARIANT_TYPE ("a{ss}"));
  g_variant_builder_add (&details, "{ss}", "Enabled", "true");
  g_variant_builder_add (&details, "{ss}", "FilesEnabled", "true");
  g_variant_builder_add (&details, "{ss}", "Uri", uri);

  goa_manager_call_add_account (
    goa_client_get_manager (data->client),
    goa_provider_get_provider_type (provider),
    email,
    email,
    g_variant_builder_end (&credentials),
    g_variant_builder_end (&details),
    cancellable,
    (GAsyncReadyCallback) add_drive_account_credentials_cb,
    g_object_ref (task));
}

static void
goa_proton_drive_provider_add_account (GoaProvider         *provider,
                                       GoaClient           *client,
                                       GtkWindow           *parent,
                                       GCancellable        *cancellable,
                                       GAsyncReadyCallback  callback,
                                       gpointer             user_data)
{
  AddDriveAccountData *data;
  g_autoptr(GTask) task = NULL;
  GtkWidget *group;

  data = g_new0 (AddDriveAccountData, 1);
  data->dialog = goa_provider_dialog_new (provider, client, parent);
  data->client = g_object_ref (client);

  task = g_task_new (provider, cancellable, callback, user_data);
  g_task_set_check_cancellable (task, FALSE);
  g_task_set_source_tag (task, goa_proton_drive_provider_add_account);
  g_task_set_task_data (task, data, add_drive_account_data_free);
  goa_provider_task_bind_window (task, GTK_WINDOW (data->dialog));

  goa_provider_dialog_add_page (data->dialog,
                                _("Proton Drive"),
                                _("rclone must be installed with a \"proton:\" remote configured."));
  group = goa_provider_dialog_add_group (data->dialog, NULL);
  data->email_entry = goa_provider_dialog_add_entry (data->dialog, group, _("_Email"));
  goa_provider_dialog_add_description (data->dialog, NULL,
    _("Enter your Proton account email address."));

  g_signal_connect_object (data->dialog,
                           "notify::state",
                           G_CALLBACK (add_drive_account_action_cb),
                           task,
                           0);
  gtk_widget_grab_focus (data->email_entry);
  gtk_window_present (GTK_WINDOW (data->dialog));
}

/* ---- refresh_account (async) ---- */

static void
goa_proton_drive_provider_refresh_account (GoaProvider         *provider,
                                           GoaClient           *client,
                                           GoaObject           *object,
                                           GtkWindow           *parent,
                                           GCancellable        *cancellable,
                                           GAsyncReadyCallback  callback,
                                           gpointer             user_data)
{
  g_autoptr(GTask) task = NULL;

  task = g_task_new (provider, cancellable, callback, user_data);
  g_task_set_source_tag (task, goa_proton_drive_provider_refresh_account);

  if (!goa_proton_rclone_available ())
    {
      g_task_return_new_error (task, GOA_ERROR, GOA_ERROR_FAILED,
                               _("rclone is not installed."));
      return;
    }

  if (!goa_proton_drive_mount_exists ())
    {
      g_task_return_new_error (task, GOA_ERROR, GOA_ERROR_FAILED,
                               _("Proton Drive mount point ~/ProtonDrive does not exist.\n"
                                 "Please start the proton-drive-bridge service."));
      return;
    }

  g_task_return_boolean (task, TRUE);
}

/* ---- ensure_credentials_sync ---- */

static gboolean
goa_proton_drive_provider_ensure_credentials_sync (GoaProvider   *provider,
                                                    GoaObject     *object,
                                                    gint          *out_expires_in,
                                                    GCancellable  *cancellable,
                                                    GError       **error)
{
  if (!goa_proton_rclone_available ())
    {
      g_set_error (error, GOA_ERROR, GOA_ERROR_FAILED,
                   _("rclone is not installed"));
      return FALSE;
    }

  if (!goa_proton_drive_mount_exists ())
    {
      g_set_error (error, GOA_ERROR, GOA_ERROR_FAILED,
                   _("Proton Drive mount point ~/ProtonDrive not found"));
      return FALSE;
    }

  if (out_expires_in != NULL)
    *out_expires_in = 0;

  return TRUE;
}

/* ---- build_object ---- */

static gboolean
goa_proton_drive_provider_build_object (GoaProvider         *provider,
                                        GoaObjectSkeleton   *object,
                                        GKeyFile            *key_file,
                                        const gchar         *group,
                                        GDBusConnection     *connection,
                                        gboolean             just_added,
                                        GError             **error)
{
  GoaFiles *files;
  g_autofree gchar *uri = NULL;

  /* Chain up to parent to set base account properties */
  if (!GOA_PROVIDER_CLASS (goa_proton_drive_provider_parent_class)->build_object (
        provider, object, key_file, group, connection, just_added, error))
    return FALSE;

  files = goa_object_get_files (GOA_OBJECT (object));
  if (files == NULL)
    {
      uri = g_strdup_printf (PROTON_DRIVE_URI, g_get_home_dir ());
      files = GOA_FILES (goa_files_skeleton_new ());
      g_object_set (files, "uri", uri, NULL);
      goa_object_skeleton_set_files (object, files);
    }
  g_object_unref (files);

  return TRUE;
}

static guint
goa_proton_drive_provider_get_credentials_generation (GoaProvider *provider)
{
  return 1;
}

static void
goa_proton_drive_provider_init (GoaProtonDriveProvider *self)
{
}

static void
goa_proton_drive_provider_class_init (GoaProtonDriveProviderClass *klass)
{
  GoaProviderClass *provider_class = GOA_PROVIDER_CLASS (klass);

  provider_class->get_provider_type          = goa_proton_drive_provider_get_provider_type;
  provider_class->get_provider_name          = goa_proton_drive_provider_get_provider_name;
  provider_class->get_provider_group         = goa_proton_drive_provider_get_provider_group;
  provider_class->get_provider_icon          = goa_proton_drive_provider_get_provider_icon;
  provider_class->get_provider_features      = goa_proton_drive_provider_get_provider_features;
  provider_class->add_account                = goa_proton_drive_provider_add_account;
  provider_class->refresh_account            = goa_proton_drive_provider_refresh_account;
  provider_class->ensure_credentials_sync    = goa_proton_drive_provider_ensure_credentials_sync;
  provider_class->build_object               = goa_proton_drive_provider_build_object;
  provider_class->get_credentials_generation = goa_proton_drive_provider_get_credentials_generation;
}

