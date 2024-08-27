import 'package:xml/xml.dart';
import 'dart:math';

enum PlayType {
  Video,
  Image,
  Audio,
}

class DeviceInfo {
  final String URLBase;
  final String deviceType;
  final String friendlyName;
  final List<dynamic> serviceList;
  DeviceInfo(
      this.URLBase, this.deviceType, this.friendlyName, this.serviceList);
}

class PositionParser {
  String TrackDuration = "00:00:00"; // 总时长
  String TrackURI = "";
  String RelTime = "00:00:00"; // 当前播放时间点
  String AbsTime = "00:00:00";

  int get TrackDurationInt {
    return toInt(TrackDuration);
  }

  int get RelTimeInt {
    return toInt(RelTime);
  }

  PositionParser(String text) {
    if (text.isEmpty) {
      return;
    }
    final doc = XmlDocument.parse(text);
    final duration = doc.findAllElements('TrackDuration').first.text;
    final rel = doc.findAllElements('RelTime').first.text;
    final abs = doc.findAllElements('AbsTime').first.text;
    if (duration.isNotEmpty) {
      TrackDuration = duration;
    }
    if (rel.isNotEmpty) {
      RelTime = rel;
    }
    if (abs.isNotEmpty) {
      AbsTime = abs;
    }
    TrackURI = doc.findAllElements('TrackURI').first.text;
  }

  String seek(int n) {
    final total = TrackDurationInt;
    var x = RelTimeInt + n;
    if (x > total) {
      x = total;
    } else if (x < 0) {
      x = 0;
    }
    return toStr(x);
  }

  static int toInt(String str) {
    final arr = str.split(':');
    var sum = 0;
    for (var i = 0; i < arr.length; i++) {
      sum += int.parse(arr[i]) * (pow(60, arr.length - i - 1) as int);
    }
    return sum;
  }

  static String toStr(int time) {
    final h = (time / 3600).floor();
    final m = ((time - 3600 * h) / 60).floor();
    final s = time - 3600 * h - 60 * m;
    final str = "${z(h)}:${z(m)}:${z(s)}";
    return str;
  }

  static String z(int n) {
    if (n > 9) {
      return n.toString();
    }
    return "0$n";
  }
}

class VolumeParser {
  int current = 0;
  VolumeParser(String text) {
    final doc = XmlDocument.parse(text);
    String v = doc.findAllElements('CurrentVolume').first.text;
    current = int.parse(v);
  }

  int change(int v) {
    int target = current + v;
    if (target > 100) {
      target = 100;
    }
    if (target < 0) {
      target = 0;
    }
    return target;
  }
}

class TransportInfoParser {
  String CurrentTransportState = '';
  String CurrentTransportStatus = '';
  TransportInfoParser(String text) {
    final doc = XmlDocument.parse(text);
    CurrentTransportState =
        doc.findAllElements('CurrentTransportState').first.text;
    CurrentTransportStatus =
        doc.findAllElements('CurrentTransportStatus').first.text;
  }
}

class MediaInfoParser {
  String MediaDuration = '00:00';
  String CurrentURI = '';
  String NextURI = '';

  int get MediaDurationInt {
    return PositionParser.toInt(MediaDuration);
  }

  MediaInfoParser(String text) {
    final doc = XmlDocument.parse(text);
    MediaDuration = doc.findAllElements('MediaDuration').first.text;
    CurrentURI = doc.findAllElements('CurrentURI').first.text;
    NextURI = doc.findAllElements('NextURI').first.text;
  }
}

class DeviceInfoParser {
  final String text;
  final XmlDocument doc;
  DeviceInfoParser(this.text) : doc = XmlDocument.parse(text);
  DeviceInfo parse(Uri uri) {
    String URLBase = "";
    try {
      URLBase = doc.findAllElements('URLBase').first.text;
    } catch (e) {
      URLBase = uri.origin;
    }
    final deviceType = doc.findAllElements('deviceType').first.text;
    final friendlyName = doc.findAllElements('friendlyName').first.text;
    final serviceList =
        doc.findAllElements('serviceList').first.findAllElements('service');
    final serviceListItems = [];
    for (final service in serviceList) {
      final serviceType = service.findElements('serviceType').first.text;
      final serviceId = service.findElements('serviceId').first.text;
      final controlURL = service.findElements('controlURL').first.text;
      serviceListItems.add({
        "serviceType": serviceType,
        "serviceId": serviceId,
        "controlURL": controlURL,
      });
    }
    return DeviceInfo(URLBase, deviceType, friendlyName, serviceListItems);
  }
}

class URIResource {
  final String? protocolInfo;
  final Duration? duration;
  final int? size;
  final String? bitrate;
  final String? url;

  URIResource({
    this.protocolInfo = 'http-get:*::',
    this.duration,
    this.size,
    this.bitrate,
    this.url,
  });

  URIResource copyWith({
    String? protocolInfo,
    Duration? duration,
    int? size,
    String? bitrate,
    String? url,
  }) {
    return URIResource(
      protocolInfo: protocolInfo ?? this.protocolInfo,
      duration: duration ?? this.duration,
      size: size ?? this.size,
      bitrate: bitrate ?? this.bitrate,
      url: url ?? this.url,
    );
  }

  factory URIResource.fromXmlString(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final element = document.findAllElements('res').first;
    return URIResource.fromXmlElement(element);
  }

  factory URIResource.fromXmlElement(XmlElement element) {
    final protocolInfo = element.getAttribute('protocolInfo');
    final duration = element.getAttribute('duration');
    final size = element.getAttribute('size');
    final bitrate = element.getAttribute('bitrate');
    final url = element.innerText;
    return URIResource(
      protocolInfo: protocolInfo,
      duration: duration == null || duration.isEmpty
          ? null
          : parseDurationISO8601(duration),
      size: size == null || size.isEmpty ? null : int.parse(size),
      bitrate: bitrate == null || bitrate.isEmpty ? null : bitrate,
      url: url,
    );
  }

  String toXmlString() {
    XmlElement element = toXmlElement();
    return element.toXmlString(pretty: true);
  }

  XmlElement toXmlElement() {
    final builder = XmlBuilder();
    builder.element('res',
        attributes: {
          if (protocolInfo != null) 'protocolInfo': protocolInfo!,
          if (duration != null) 'duration': durationToStringISO8601(duration!),
          if (size != null) 'size': size!.toString(),
          if (bitrate != null) 'bitrate': bitrate!,
        },
        nest: url ?? '');
    return builder.buildDocument().rootElement;
  }
}

class URIMetadata {
  final String id;
  final String parentID;
  final bool? restricted;
  final String? refID;
  final String? title;
  final String? creator;
  final String upnpClass;
  final String? albumArtURI;
  final String? genre;
  final String? artist;
  final int? originalTrackNumber;
  final String? artistRole;
  final DateTime? date;
  final String? producer;
  final URIResource? res;

  static const String upnpClassVideo = "object.item.videoItem";
  static const String upnpClassAudio = "object.item.audioItem";
  static const String upnpClassPhoto = "object.item.imageItem";

  const URIMetadata({
    this.id = "0",
    this.parentID = "1",
    this.restricted,
    this.refID,
    this.title,
    this.creator,
    this.upnpClass = upnpClassVideo,
    this.albumArtURI,
    this.genre,
    this.artist,
    this.originalTrackNumber,
    this.artistRole,
    this.date,
    this.producer,
    this.res,
  });

  URIMetadata copyWith({
    String? id,
    String? parentID,
    bool? restricted,
    String? refID,
    String? title,
    String? creator,
    String? upnpClass,
    String? albumArtURI,
    String? genre,
    String? artist,
    int? originalTrackNumber,
    String? artistRole,
    DateTime? date,
    String? producer,
    URIResource? res,
  }) {
    return URIMetadata(
      id: id ?? this.id,
      parentID: parentID ?? this.parentID,
      restricted: restricted ?? this.restricted,
      refID: refID ?? this.refID,
      title: title ?? this.title,
      creator: creator ?? this.creator,
      upnpClass: upnpClass ?? this.upnpClass,
      albumArtURI: albumArtURI ?? this.albumArtURI,
      genre: genre ?? this.genre,
      artist: artist ?? this.artist,
      originalTrackNumber: originalTrackNumber ?? this.originalTrackNumber,
      artistRole: artistRole ?? this.artistRole,
      date: date ?? this.date,
      producer: producer ?? this.producer,
      res: res ?? this.res,
    );
  }

  factory URIMetadata.fromXmlElement(XmlElement element) {
    final id = element.getAttribute('id') ?? '';
    final parentID = element.getAttribute('parentID') ?? '';
    final restricted =
        element.getAttribute('restricted') == '1' ? true : false;
    final refID = element.getAttribute('refID');
    var elements = element.findElements('dc:title');
    final title = elements.isNotEmpty ? elements.first.innerText : '';
    elements = element.findElements('upnp:class');
    final upnpClass = elements.isNotEmpty ? elements.first.innerText : '';
    final albumArtURI = element.getAttribute('albumArtURI');
    final genre = element.getAttribute('genre');
    final artist = element.getAttribute('artist');
    final originalTrackNumber = element.getAttribute('originalTrackNumber');
    final artistRole = element.getAttribute('artistRole');
    final date = element.getAttribute('date');
    final producer = element.getAttribute('producer');
    final resElement = element.findElements('res');
    final res = resElement.isNotEmpty
        ? URIResource.fromXmlElement(resElement.first)
        : null;
    return URIMetadata(
      id: id,
      parentID: parentID,
      restricted: restricted,
      refID: refID,
      title: title,
      upnpClass: upnpClass,
      albumArtURI: albumArtURI,
      genre: genre,
      artist: artist,
      originalTrackNumber:
          originalTrackNumber == null ? null : int.parse(originalTrackNumber),
      artistRole: artistRole,
      date: date == null ? null : DateTime.parse(date),
      producer: producer,
      res: res,
    );
  }

  factory URIMetadata.fromXmlString(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    return URIMetadata.fromXmlElement(document.findAllElements('item').first);
  }


  XmlElement toXmlElement() {
    final builder = XmlBuilder();
    builder.element('DIDL-Lite', 
      namespaces: {
        'urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/': '',
        'http://purl.org/dc/elements/1.1/': 'dc',
        'urn:schemas-upnp-org:metadata-1-0/upnp/': 'upnp',
        'http://www.sec.co.kr/dlna/': 'sec',
        'urn:scehmas-dlna-org:metadata-1-0/': 'dlna',
      }, 
      nest: () {
        builder.element('item', 
          attributes: {
            'id': id,
            'parentID': parentID,
            if (restricted!=null) 'restricted': restricted! ? '1' : '0',
            if (refID!=null) 'refID': refID!,
          },
          nest: () {
            builder.element('dc:title', nest: title);
            if (creator != null) {
              builder.element('dc:creator', nest: creator!);
            }
            builder.element('upnp:class', nest: upnpClass);
            if (albumArtURI != null) {
              builder.element('upnp:albumArtURI', nest: albumArtURI!);
            }
            if (genre != null) {
              builder.element('upnp:genre', nest: genre!);
            }
            if (artist != null) {
              builder.element('upnp:artist', nest: artist!);
            }
            if (originalTrackNumber != null) {
              builder.element('upnp:originalTrackNumber', nest: originalTrackNumber!.toString());
            }
            if (artistRole != null) {
              builder.element('upnp:artistRole', nest: artistRole!);
            }
            if (date != null) {
              builder.element('dc:date', nest: date!.toIso8601String());
            }
            if (producer != null) {
              builder.element('upnp:producer', nest: producer!);
            }
            if (res != null) {
              var resElement = res!.toXmlElement();
              var attributes = <String, String>{};
              for (var attribute in resElement.attributes) {
                attributes[attribute.name.toString()] = attribute.value;
              }
              builder.element("res", attributes: attributes, nest: resElement.innerText);
            }
          }
      );
      }
    );
    return builder.buildDocument().rootElement;
  }

  String toXmlString() {
    XmlElement element = toXmlElement();
    return element.toXmlString(pretty: true);
  }
}

class MediaInfo {
  final int nrTracks;
  final Duration mediaDuration;
  final String? currentURI;
  final URIMetadata? currentURIMetaData;
  final String? nextURI;
  final URIMetadata? nextURIMetaData;
  final String playMedium;
  final String recordMedium;
  final String writeStatus;

  MediaInfo({
    required this.nrTracks,
    required this.mediaDuration,
    this.currentURI,
    this.currentURIMetaData,
    this.nextURI,
    this.nextURIMetaData,
    required this.playMedium,
    this.recordMedium = 'NOT_IMPLEMENTED',
    this.writeStatus = 'NOT_IMPLEMENTED',
  });

  factory MediaInfo.fromXMLString(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final element  = document.firstElementChild!;
    final nrTracks = int.parse(_getElementText(element, 'NrTracks') ?? '0');
    final mediaDuration =
        parseDuration(_getElementText(element, 'MediaDuration') ?? '0:00:00');
    String? currentURI = _getElementText(element, 'CurrentURI');
    if (currentURI != null && currentURI.trim().isEmpty) {
      currentURI = null;
    }
    String uriMetaData =
        (_getElementText(element, 'CurrentURIMetaData') ?? '').trim();
    URIMetadata? currentURIMetaData;
    try{
      currentURIMetaData = URIMetadata.fromXmlString(uriMetaData);
    }
    catch(e){
    }
    final nextURI = _getElementText(element, 'NextURI');
    String nextUriMetaData =
        (_getElementText(element, 'NextURIMetaData') ?? '').trim();
    URIMetadata? nextURIMetaData;
    try{
      nextURIMetaData = URIMetadata.fromXmlString(nextUriMetaData);
    }
    catch(e){
    }
    final playMedium = _getElementText(element, 'PlayMedium') ?? 'UNKNOWN';
    final recordMedium =
        _getElementText(element, 'RecordMedium') ?? 'NOT_IMPLEMENTED';
    final writeStatus =
        _getElementText(element, 'WriteStatus') ?? 'NOT_IMPLEMENTED';

    return MediaInfo(
      nrTracks: nrTracks,
      mediaDuration: mediaDuration,
      currentURI: currentURI,
      currentURIMetaData: currentURIMetaData,
      nextURI: nextURI,
      nextURIMetaData: nextURIMetaData,
      playMedium: playMedium,
      recordMedium: recordMedium,
      writeStatus: writeStatus,
    );
  }

  
  String toXml() {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="utf-8"');
    builder.element('s:Envelope', nest: () {
      builder.attribute('xmlns:s', 'http://schemas.xmlsoap.org/soap/envelope/');
      builder.attribute(
          's:encodingStyle', 'http://schemas.xmlsoap.org/soap/encoding/');
      builder.element('s:Body', nest: () {
        builder.element('u:GetMediaInfoResponse', nest: () {
          builder.attribute(
              'xmlns:u', 'urn:schemas-upnp-org:service:AVTransport:1');
          builder.element('NrTracks', nest: nrTracks.toString());
          builder.element('MediaDuration',
              nest: durationToString(mediaDuration));
          builder.element('CurrentURI', nest: currentURI);
          if (currentURIMetaData != null) {
            builder.element('CurrentURIMetaData',
                nest: currentURIMetaData!.toXmlString());
          }
          builder.element('NextURI', nest: nextURI);
          if (nextURIMetaData != null) {
            builder.element('NextURIMetaData',
                nest: nextURIMetaData!.toXmlString());
          }
          builder.element('PlayMedium', nest: playMedium);
          builder.element('RecordMedium', nest: recordMedium);
          builder.element('WriteStatus', nest: writeStatus);
        });
      });
    });

    return builder.buildDocument().toXmlString(pretty: true);
  }
}

class PositionInfo{
  final int track;
  final Duration trackDuration;
  final URIMetadata? trackMetaData;
  final String? trackURI;
  final Duration? relTime;
  final Duration? absTime;
  final int? relCount;
  final int? absCount;

  PositionInfo({
    required this.track,
    required this.trackDuration,
    this.trackMetaData,
    this.trackURI,
    this.relTime,
    this.absTime,
    this.relCount,
    this.absCount,
  });
  factory PositionInfo.fromXMLString(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final element  = document.firstElementChild!;
    return PositionInfo.fromXMLElement(element);
  }
  factory PositionInfo.fromXMLElement(XmlElement element) {
    final track = int.parse(_getElementText(element, 'Track') ?? '0');
    final trackDuration =
        parseDuration(_getElementText(element, 'TrackDuration') ?? '0:00:00');
    URIMetadata? trackMetaData;
    try{
      trackMetaData = URIMetadata.fromXmlString(_getElementText(element, 'TrackMetaData')!);
    }
    catch(e){
    }

    String? trackURI = _getElementText(element, 'TrackURI');
    if (trackURI != null && trackURI.trim().isEmpty) {
      trackURI = null;
    }

    final relTime = _parseOrNull<Duration>(_getElementText(element, "RelTime"), parseDuration);
    final absTime = _parseOrNull<Duration>(_getElementText(element, "AbsTime"), parseDuration);
    final relCount = _parseOrNull<int>(_getElementText(element, "RelCount"), int.parse);
    final absCount = _parseOrNull<int>(_getElementText(element, "AbsCount"), int.parse);
    return PositionInfo(
      track: track,
      trackDuration: trackDuration,
      trackMetaData: trackMetaData,
      trackURI: trackURI,
      relTime: relTime,
      absTime: absTime,
      relCount: relCount,
      absCount: absCount,
    );

  }
}

class TransportInfo {
  final String currentTransportState;
  final String currentTransportStatus;
  final String currentSpeed;
  static const String playing = 'PLAYING';
  static const String stopped = 'STOPPED';
  static const String paused = 'PAUSED_PLAYBACK';
  static const String pausedRecording = 'PAUSED_RECORDING';
  static const String scanning = 'SCANNING';
  static const String noMediaPresent = 'NO_MEDIA_PRESENT';
  static const String transitioning = 'TRANSITIONING';
  static const String recording = 'RECORDING';
  static const String disconnected = 'DISCONNECTED';
  TransportInfo({
    required this.currentTransportState,
    required this.currentTransportStatus,
    this.currentSpeed = '1',
  });
  factory TransportInfo.fromXMLString(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final element  = document.firstElementChild!;
    return TransportInfo.fromXMLElement(element);
  }
  factory TransportInfo.fromXMLElement(XmlElement element) {
    final currentTransportState =
        _getElementText(element, 'CurrentTransportState') ?? '';
    final currentTransportStatus =
        _getElementText(element, 'CurrentTransportStatus') ?? '';
    final currentSpeed = _getElementText(element, 'CurrentSpeed') ?? '1';
    return TransportInfo(
      currentTransportState: currentTransportState,
      currentTransportStatus: currentTransportStatus,
      currentSpeed: currentSpeed,
    );
  }
}

class DeviceCapabilities {
  final List<String> playMedia;
  final List<String> recMedia;
  final List<String> recQualityModes;
  DeviceCapabilities({
    required this.playMedia,
    required this.recMedia,
    required this.recQualityModes,
  });
  factory DeviceCapabilities.fromXMLString(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final element  = document.firstElementChild!;
    final playMedia = _getElementText(element, 'PlayMedia')?.split(',') ?? [];
    final recMedia = _getElementText(element, 'RecMedia')?.split(',') ?? [];
    final recQualityModes = _getElementText(element, 'RecQualityModes')?.split(',') ?? [];
    return DeviceCapabilities(
      playMedia: playMedia,
      recMedia: recMedia,
      recQualityModes: recQualityModes,
    );
  }

}

class VolumeResponse{
  final int volume;
  VolumeResponse(this.volume);
  factory VolumeResponse.fromXMLString(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final element  = document.firstElementChild!;
    final volume = int.parse(_getElementText(element, 'CurrentVolume') ?? '0');
    return VolumeResponse(volume);
  } 
}

class MuteResponse{
  final bool mute;
  MuteResponse(this.mute);
  factory MuteResponse.fromXMLString(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final element  = document.firstElementChild!;
    final mute = int.parse(_getElementText(element, 'CurrentMute') ?? '0');
    return MuteResponse(mute == 1);
  }
}

String? _getElementText(XmlElement element, String tagName) {
  var elements = element.findAllElements(tagName);
  if (elements.isEmpty) {
    return null;
  }
  var text = elements.first.innerText.trim();
  return text.isEmpty ? null : text;
}

T? _parseOrNull<T>(String? text, T Function(String) parser) {
  if (text == null || text.trim().isEmpty) {
    return null;
  }
  return parser(text);
}

Duration parseDuration(String duration) {
  final parts = duration.split(':');
  if (parts.length != 3) {
    return Duration.zero;
  }
  int milliseconds = 0;
  int seconds = 0;
  if (parts[2].contains(".")){
    var subparts = parts[2].split(".");
    seconds =int.parse(subparts[0]);
    milliseconds = int.parse(subparts[1]);
  }
  else{
    seconds = int.parse(parts[2]);
  }
  return Duration(
    hours: int.parse(parts[0]),
    minutes: int.parse(parts[1]),
    seconds: seconds,
    milliseconds: milliseconds
  );
}

Duration parseDurationISO8601(String duration) {
  final parts = duration.split('T');
  if (parts.length != 2) {
    return Duration.zero;
  }
  final date = parts[0];
  final time = parts[1];
  final dateParts = date.split('-');
  if (dateParts.length != 3) {
    return Duration.zero;
  }
  final timeParts = time.split(':');
  if (timeParts.length != 3) {
    return Duration.zero;
  }
  return Duration(
    days: int.parse(dateParts[0]),
    hours: int.parse(timeParts[0]),
    minutes: int.parse(timeParts[1]),
    seconds: int.parse(timeParts[2]),
  );
}

String durationToString(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
}

String durationToStringISO8601(Duration duration) {
  String result = "PT";
  
  // Días
  if (duration.inDays > 0) {
    result += "${duration.inDays}D";
  }
  
  // Horas
  var hours = duration.inHours.remainder(24);
  if (hours > 0) {
    result += "${hours}H";
  }
  
  // Minutos
  var minutes = duration.inMinutes.remainder(60);
  if (minutes > 0) {
    result += "${minutes}M";
  }
  
  // Segundos
  var seconds = duration.inSeconds.remainder(60);
  if (seconds > 0) {
    result += "${seconds}S";
  }

  // Si la duración es cero
  if (result == "PT") {
    result = "PT0S";
  }

  return result;
}

class UPnPError extends Error {
  final String code;
  final String description;
  UPnPError(this.code, this.description);
  @override
  String toString() {
    return 'UPnPError{code: $code, description: $description}';
  }
}