/* goaprotonauth.h — Proton bridge helper utilities
 *
 * Copyright 2024 Proton AG
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#ifndef __GOA_PROTON_AUTH_H__
#define __GOA_PROTON_AUTH_H__

#include <glib.h>

G_BEGIN_DECLS

gboolean goa_proton_check_program              (const gchar *program_name);
gboolean goa_proton_bridge_is_running           (guint16      imap_port);
gboolean goa_proton_rclone_available            (void);
gboolean goa_proton_drive_mount_exists          (void);
gboolean goa_proton_calendar_bridge_is_running  (void);

G_END_DECLS

#endif /* __GOA_PROTON_AUTH_H__ */
