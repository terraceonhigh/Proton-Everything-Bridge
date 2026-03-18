/* goaprovider-priv.h — Private GOA provider class structure
 *
 * This file is derived from gnome-online-accounts 3.50.x source.
 * It provides the GoaProviderClass struct definition needed for
 * external provider plugins.
 *
 * Copyright 2013-2017 Red Hat, Inc.
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

#ifndef __GOA_PROVIDER_PRIV_H__
#define __GOA_PROVIDER_PRIV_H__

#include <gio/gio.h>
#include <gtk/gtk.h>
#include <goabackend/goabackend.h>

G_BEGIN_DECLS

struct _GoaProviderClass
{
  GObjectClass parent_class;

  /* pure virtual */
  void                    (*add_account)                  (GoaProvider            *self,
                                                           GoaClient              *client,
                                                           GtkWindow              *parent,
                                                           GCancellable           *cancellable,
                                                           GAsyncReadyCallback     callback,
                                                           gpointer                user_data);
  void                    (*refresh_account)              (GoaProvider            *self,
                                                           GoaClient              *client,
                                                           GoaObject              *object,
                                                           GtkWindow              *parent,
                                                           GCancellable           *cancellable,
                                                           GAsyncReadyCallback     callback,
                                                           gpointer                user_data);
  GoaProviderFeatures     (*get_provider_features)        (GoaProvider            *self);
  GoaProviderGroup        (*get_provider_group)           (GoaProvider            *self);
  gchar                  *(*get_provider_name)            (GoaProvider            *self,
                                                           GoaObject              *object);
  const gchar            *(*get_provider_type)            (GoaProvider            *self);

  /* virtual but with default implementation */
  gboolean                (*build_object)                 (GoaProvider            *self,
                                                           GoaObjectSkeleton      *object,
                                                           GKeyFile               *key_file,
                                                           const gchar            *group,
                                                           GDBusConnection        *connection,
                                                           gboolean                just_added,
                                                           GError                **error);
  gboolean                (*ensure_credentials_sync)      (GoaProvider            *self,
                                                           GoaObject              *object,
                                                           gint                   *out_expires_in,
                                                           GCancellable           *cancellable,
                                                           GError                **error);
  guint                   (*get_credentials_generation)   (GoaProvider            *self);
  GIcon                  *(*get_provider_icon)            (GoaProvider            *self,
                                                           GoaObject              *object);
  GoaObject              *(*add_account_finish)           (GoaProvider            *self,
                                                           GAsyncResult           *result,
                                                           GError                **error);
  gboolean                (*refresh_account_finish)       (GoaProvider            *self,
                                                           GAsyncResult           *result,
                                                           GError                **error);
  void                    (*remove_account)               (GoaProvider            *self,
                                                           GoaObject              *object,
                                                           GCancellable           *cancellable,
                                                           GAsyncReadyCallback     callback,
                                                           gpointer                user_data);
  gboolean                (*remove_account_finish)        (GoaProvider            *self,
                                                           GAsyncResult            *res,
                                                           GError                **error);
  void                    (*show_account)                 (GoaProvider            *self,
                                                           GoaClient              *client,
                                                           GoaObject              *object,
                                                           GtkWindow              *parent,
                                                           GCancellable           *cancellable,
                                                           GAsyncReadyCallback     callback,
                                                           gpointer                user_data);
  gboolean                (*show_account_finish)          (GoaProvider            *self,
                                                           GAsyncResult           *result,
                                                           GError                **error);
};

#define GOA_PROVIDER_EXTENSION_POINT_NAME "goa-backend-provider"

void        goa_provider_ensure_extension_points_registered    (void);

gboolean    goa_provider_build_object                          (GoaProvider            *self,
                                                                GoaObjectSkeleton      *object,
                                                                GKeyFile               *key_file,
                                                                const gchar            *group,
                                                                GDBusConnection        *connection,
                                                                gboolean                just_added,
                                                                GError                **error);

gboolean    goa_provider_ensure_credentials_sync               (GoaProvider             *self,
                                                                GoaObject               *object,
                                                                gint                    *out_expires_in,
                                                                GCancellable            *cancellable,
                                                                GError                 **error);

G_END_DECLS

#endif /* __GOA_PROVIDER_PRIV_H__ */
