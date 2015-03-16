= Gestion

Allows for handling of day-to-day tasks in a small school, think cultural center
that offers classes.

== Functions

For the cultural center-part, the following functions are implemented:

  * Rights management (for students, secretary, director, admin, ...)
  * Creation of courses (using templates for different courses)
    * Sign up of students to courses
    * Entering grades of students
    * Creating diplomas
  * Accounting
    * Payments of students
    * Internet-usage
    * Other, simple 2-way accounting

There is also a network-part which has the following functions:

  * Sharing with samba (public, read and read-write access)
  * Internet-gateway using usb-modems or Ethernet-port
  * Access-control of students when installed as captive gateway
  * Controlling internet-credit, works for now only for Chad

== Hardware

It has been tested on ArchLinux running on different ARM-boxes (Dreamplug,
Smileplug and Cubox-i). Most of the parts also run on Ubuntu.

== Software

The user-interface is using http://QooxDoo.org with a ruby-back-end called
QooxView. Different libraries are used:

  * AfriCompta - simple accounting program for QooxView
  * HelperClasses - some modules to make life easier
  * HilinkModem - interface for the infamous hilinkmodems which lack USSD-support!
  * Network - captive interface and usb-modems definition
  * QooxView - RPC backend for QooxDoo, also implementing a simple ActiveRecord
    backend with CSV-files
  * SerialModem - interface for simple ttyUSB-modems

== Installation

Download the different parts under 'Software' from GitHub and put them all in one
directory. Then you can cd into 'Gestion' and run ```./Gestion``` which will do
some basic checks and offer to install missing packages.

An installation-package for ArchLinux is in preparation.