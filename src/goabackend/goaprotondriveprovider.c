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

#include <glib/gi18n.h>
#include <gio/gio.h>

#define PROTON_DRIVE_PROVIDER_TYPE "proton_drive"
#define PROTON_DRIVE_URI           "file://%s/ProtonDrive"

struct _GoaProtonDriveProvider
{
  GoaProvider parent_instance;
};

G_DEFINE_DYNAMIC_TYPE (GoaProtonDriveProvider,
                       goa_proton_drive_provider,
                       GOA_TYPE_PROVIDER)

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
  return g_themed_icon_new_with_default_fallbacks ("proton-drive-symbolic");
}

static GoaProviderFeatures
goa_proton_drive_provider_get_provider_features (GoaProvider *provider)
{
  return GOA_PROVIDER_FEATURE_FILES;
}

static GoaObject *
goa_proton_drive_provider_add_account (GoaProvider  *provider,
                                       GoaClient    *client,
                                       GtkDialog    *dialog,
                                       GtkBox       *vbox,
                                       GError      **error)
{
  g_set_error_literal (error,
                       GOA_ERROR,
                       GOA_ERROR_NOT_SUPPORTED,
                       "Proton Drive account setup is not yet implemented");
  return NULL;
}

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

  uri = g_strdup_printf (PROTON_DRIVE_URI, g_get_home_dir ());

  files = GOA_FILES (goa_files_skeleton_new ());
  g_object_set (files,
                "uri", uri,
                NULL);

  goa_object_skeleton_set_files (object, files);
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
  provider_class->get_provider_icon          = goa_proton_drive_provider_get_provider_icon;
  provider_class->get_provider_features      = goa_proton_drive_provider_get_provider_features;
  provider_class->add_account                = goa_proton_drive_provider_add_account;
  provider_class->build_object               = goa_proton_drive_provider_build_object;
  provider_class->get_credentials_generation = goa_proton_drive_provider_get_credentials_generation;
}

static void
goa_proton_drive_provider_class_finalize (GoaProtonDriveProviderClass *klass)
{
}
