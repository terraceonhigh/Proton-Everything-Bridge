/* goaproviderdialog.h — Local declarations for GoaProviderDialog
 *
 * These declarations are derived from gnome-online-accounts 3.50.x source.
 * GoaProviderDialog is exported by libgoa-backend but its header is not
 * installed. We declare the subset of functions we need here.
 *
 * Copyright 2023 GNOME Foundation Inc.
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

#ifndef __GOA_PROVIDER_DIALOG_LOCAL_H__
#define __GOA_PROVIDER_DIALOG_LOCAL_H__

#include <adwaita.h>
#include <goa/goa.h>

G_BEGIN_DECLS

typedef enum
{
  GOA_DIALOG_IDLE,
  GOA_DIALOG_READY,
  GOA_DIALOG_BUSY,
  GOA_DIALOG_ERROR,
  GOA_DIALOG_DONE,
} GoaDialogState;

/* Forward-declare GoaProvider to avoid circular includes */
typedef struct _GoaProvider GoaProvider;
typedef struct _GoaClient  GoaClient;

#define GOA_TYPE_PROVIDER_DIALOG (goa_provider_dialog_get_type ())

G_DECLARE_FINAL_TYPE (GoaProviderDialog, goa_provider_dialog, GOA, PROVIDER_DIALOG, AdwWindow)

GoaProviderDialog   *goa_provider_dialog_new                (GoaProvider       *provider,
                                                             GoaClient         *client,
                                                             GtkWindow         *parent);
GoaDialogState       goa_provider_dialog_get_state          (GoaProviderDialog *self);
void                 goa_provider_dialog_set_state          (GoaProviderDialog *self,
                                                             GoaDialogState     state);
void                 goa_provider_dialog_push_account       (GoaProviderDialog *self,
                                                             GoaObject         *object,
                                                             GtkWidget         *content);
void                 goa_provider_dialog_report_error       (GoaProviderDialog *self,
                                                             const GError      *error);

/* UI Helpers */
GtkWidget           *goa_provider_dialog_add_page           (GoaProviderDialog *self,
                                                             const char        *title,
                                                             const char        *description);
GtkWidget           *goa_provider_dialog_add_group          (GoaProviderDialog *self,
                                                             const char        *title);
GtkWidget           *goa_provider_dialog_add_entry          (GoaProviderDialog *self,
                                                             GtkWidget         *group,
                                                             const char        *label);
GtkWidget           *goa_provider_dialog_add_description    (GoaProviderDialog *self,
                                                             GtkWidget         *target,
                                                             const char        *description);

/* GTask Helpers */
void                 goa_provider_task_bind_window          (GTask             *task,
                                                             GtkWindow         *window);
void                 goa_provider_task_return_account       (GTask             *task,
                                                             GoaObject         *object);
void                 goa_provider_task_return_error         (GTask             *task,
                                                             GError            *error);

G_END_DECLS

#endif /* __GOA_PROVIDER_DIALOG_LOCAL_H__ */
