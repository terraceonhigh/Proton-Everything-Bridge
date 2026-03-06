/* goaprotonmailprovider.h — GOA provider header for Proton Mail
 *
 * Copyright 2024 Proton AG
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#ifndef __GOA_PROTON_MAIL_PROVIDER_H__
#define __GOA_PROTON_MAIL_PROVIDER_H__

#include <goabackend/goabackend.h>
#include "goaprovider-priv.h"

G_BEGIN_DECLS

G_DECLARE_FINAL_TYPE (GoaProtonMailProvider,
                      goa_proton_mail_provider,
                      GOA, PROTON_MAIL_PROVIDER,
                      GoaProvider)

G_END_DECLS

#endif /* __GOA_PROTON_MAIL_PROVIDER_H__ */
