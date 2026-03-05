/* goaprotonauth.c — Proton bridge helper utilities
 *
 * Copyright 2024 Proton AG
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * Helpers for discovering Proton Mail Bridge credentials and
 * verifying that required bridge processes are running.
 */

#include <glib.h>
#include <gio/gio.h>

/* Check whether a given program is available in $PATH */
gboolean
goa_proton_check_program (const gchar *program_name)
{
  g_autofree gchar *path = g_find_program_in_path (program_name);
  return (path != NULL);
}

/* Check whether the Proton Mail Bridge is reachable on localhost */
gboolean
goa_proton_bridge_is_running (guint16 imap_port)
{
  g_autoptr(GSocketClient) client = g_socket_client_new ();
  g_autoptr(GSocketConnection) conn = NULL;
  g_autoptr(GError) error = NULL;

  conn = g_socket_client_connect_to_host (client,
                                          "127.0.0.1",
                                          imap_port,
                                          NULL,
                                          &error);
  if (conn == NULL)
    {
      g_debug ("Proton Mail Bridge not reachable on port %u: %s",
               imap_port, error->message);
      return FALSE;
    }

  return TRUE;
}

/* Check whether rclone is installed */
gboolean
goa_proton_rclone_available (void)
{
  return goa_proton_check_program ("rclone");
}

/* Check whether the rclone FUSE mount point exists */
gboolean
goa_proton_drive_mount_exists (void)
{
  g_autofree gchar *mount_path = NULL;

  mount_path = g_build_filename (g_get_home_dir (), "ProtonDrive", NULL);
  return g_file_test (mount_path, G_FILE_TEST_IS_DIR);
}

/* Check whether the Proton Calendar Bridge CalDAV endpoint is responding */
gboolean
goa_proton_calendar_bridge_is_running (void)
{
  g_autoptr(GSocketClient) client = g_socket_client_new ();
  g_autoptr(GSocketConnection) conn = NULL;
  g_autoptr(GError) error = NULL;

  conn = g_socket_client_connect_to_host (client,
                                          "127.0.0.1",
                                          9842,
                                          NULL,
                                          &error);
  if (conn == NULL)
    {
      g_debug ("Proton Calendar Bridge not reachable: %s", error->message);
      return FALSE;
    }

  return TRUE;
}
