Protocol Buffers for Delphi
===========================

The project has a short name protobuf-delphi and ported some part of the project code from Protocol Buffers for Java.
At that time, this project seemed to me clearer and cleaner in comparison to other implementations.

Code generator project status
-----------------------------
A project for parsing and code generation is under construction. Now we have moved to the phase of code generation.
You can send your code samples and your vision. Wishes will certainly be considered and welcomed.

Why did this project come into being
------------------------------------

When Google uploaded the source code for Protocol Buffers to open source.
I was amazed at the ideas behind it, the compactness of the data and its efficiency, 
the speed of its processing, especially compared to xml.

The first version of the port on Delphi was prepared in 2007, during the project on my main job.
I had to transfer a large table with data to the client application. 
This operation was slow. The task was to somehow increase the speed of work.
and reduce the amount of traffic sent from the server to the client application over https. 
Before that, XML was used for the same purposes.

After the transition to Protocol Buffers data format was completed, it became possible to download a lot more
more data and significantly increase productivity.

Quite quickly, a port on Delphi was made, limited in functionality.
Low-level protocol abstractions were implemented, there was no code generation.
But this didn't prevent us from using it in web-services, 
and the functionality implemented was sufficient for the project.

Knowing the structure of the message, it was possible to send and receive data on this protocol.
A year later I placed the code on the site https://sourceforge.net/p/protobuf-delphi.

Other Protocol Buffers applications
----------------------------------
Probably many people will find it interesting to use for storage both on disk and inside the program. 

If you know the features of physical storage of data in the protocol buffer, 
you can do interesting things. 

At the beginning of a record there is a field that stores the length of the record. 
You can also always skip unnecessary record fields.
Depending on the type they have either a fixed length or if the field has a variable length, then the beginning of the field will contain the length of this field.
So it is easy to separate the records from each other, and sometimes it can be useful to skip the unnecessary part of the record.

Data in the tree can be indexed by a B-tree structure or hashmap, for example.
This allows you to get quick random access to the record you are looking for by key.

The reading process can be applied to a single packed record.

The data in this format have significant compression. 
compared to the usual storage of objects in memory:
 - the binary data is written quite efficiently;
 - fields with values equal to the default value are not written;
 - to this structure, you can add a dictionary for frequently used character values.

In our project we have saved a lot of memory consumption. 
compared to storing normal objects.
In some cases the gain was 20 or more times and without loss of data access speed. This is especially useful if the data is immutable.

Similar formats are used for physical data storage in industrial DBMS.

That is, in skillful hands, this data format is a powerful thing.

A bit of history
---------------

By the way, of course, not everything in this format is an invention of Google.
Rather, little has been invented by Google.   

IMHO legs grow out of ASN.1 format. When I saw the documentation of this format I was amazed how much they match.

The most important merit of Google in promoting this data format and in publishing the source code in open source.

ASN.1 is similar in purpose and use to protocol buffers and Apache Thrift, which are also interface description languages for cross-platform data serialization. Like those languages, it has a schema (in ASN.1, called a "module"), and a set of encodings, typically type-length-value encodings. However, ASN.1, defined in 1984, predates them by many years. It also includes a wider variety of basic data types, some of which are obsolete, and has more options for extensibility. A single ASN.1 message can include data from multiple modules defined in multiple standards, even standards defined years apart.
