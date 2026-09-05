/* ***** BEGIN LICENSE BLOCK *****
 * This file is part of Natron <https://natrongithub.github.io/>,
 * (C) 2018-2023 The Natron developers
 * (C) 2013-2018 INRIA and Alexandre Gauthier-Foichat
 *
 * Natron is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Natron is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Natron.  If not, see <http://www.gnu.org/licenses/gpl-2.0.html>
 * ***** END LICENSE BLOCK ***** */
#ifndef NATRON_GLOBAL_QTCOMPAT_H
#define NATRON_GLOBAL_QTCOMPAT_H

#include "Global/Macros.h"

#include <QtGlobal> // for Q_OS_*
#include <QString>
#include <QUrl>
#include <QFileInfo>
#include <QMutex>

QT_BEGIN_NAMESPACE
class QEvent;
class QMutex;
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
// Declared, not included: QEnterEvent is a QtGui type and this header must not
// pull QtGui into the Engine build.
class QEnterEvent;
#endif
QT_END_NAMESPACE

NATRON_NAMESPACE_ENTER

namespace QtCompat {
/*Removes the . and the extension from the filename and also
 * returns the extension as a string.*/
inline QString
removeFileExtension(QString & filename)
{
    //qDebug() << "remove file ext from" << filename;
    QFileInfo fi(filename);
    QString extension = fi.suffix();

    if ( !extension.isEmpty() ) {
        filename.truncate(filename.size() - extension.size() - 1);
    }

    //qDebug() << "->" << filename << fi.suffix();
    return extension;
}

// Define compatibility typedefs so code builds with Qt5 & Qt6.
//
// Qt 5 delivered enter events as a plain QEvent; Qt 6 introduced QEnterEvent.
// The Qt 6 alias has to name the global type explicitly: written unqualified it
// would refer to the typedef being declared. A forward declaration is enough,
// which matters because QEnterEvent belongs to QtGui and this header is
// included by Engine, which links only QtCore, QtNetwork and QtConcurrent.
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
typedef ::QEnterEvent QEnterEvent;
#elif QT_VERSION >= QT_VERSION_CHECK(5, 0, 0)
typedef ::QEvent QEnterEvent;
#else
#error "Unsupported version of QT"
#endif

// Qt 6 turned QMutexLocker into a class template and split QMutex from
// QRecursiveMutex, so the locker is parameterised on which mutex it holds.
// Declaring a plain local still works there through class template argument
// deduction, but naming the type -- in a smart pointer, a container or a cast --
// needs the argument. Qt 5's QMutexLocker takes any QMutex, so the parameter is
// simply ignored there.
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
template<typename Mutex> using MutexLocker = ::QMutexLocker<Mutex>;
#else
template<typename Mutex> using MutexLocker = ::QMutexLocker;
#endif

} // namespace QtCompat

NATRON_NAMESPACE_EXIT

#endif // NATRON_GLOBAL_QTCOMPAT_H
