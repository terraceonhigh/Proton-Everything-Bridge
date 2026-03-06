/* goaprotoncalendarprovider.h — GOA provider header for Proton Calendar
 *
 * Copyright 2024 Proton AG
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#ifndef __GOA_PROTON_CALENDAR_PROVIDER_H__
#define __GOA_PROTON_CALENDAR_PROVIDER_H__

#include <goabackend/goabackend.h>
#include "goaprovider-priv.h"

G_BEGIN_DECLS

G_DECLARE_FINAL_TYPE (GoaProtonCalendarProvider,
                      goa_proton_calendar_provider,
                      GOA, PROTON_CALENDAR_PROVIDER,
                      GoaProvider)

G_END_DECLS

#endif /* __GOA_PROTON_CALENDAR_PROVIDER_H__ */
