# 1-bosqich: Dart dasturini kompilyatsiya qilish (Build stage)
FROM dart:stable AS build

WORKDIR /app

# Avval bog'liqliklarni (dependencies) yuklab olamiz
COPY pubspec.* ./
RUN dart pub get

# Qolgan barcha kodlarni nusxalaymiz
COPY . .
RUN dart pub get --offline

# Server faylini tezkor binar (executable) faylga aylantiramiz
# ESLATMA: Agar asosiy faylingiz boshqa joyda bo'lsa (masalan, bin/main.dart), pastdagi manzilni shunga moslang!
RUN dart compile exe bin/server.dart -o bin/server

# 2-bosqich: Kichik va xavfsiz obraz hosil qilish (Runtime stage)
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/

# Agar loyihada public papka yoki qo'shimcha fayllar bo'lsa, ularni ham nusxalash kerak (ixtiyoriy):
# COPY --from=build /app/public /app/public

# Render avtomatik beradigan portni tinglash
EXPOSE 8080

# Serverni ishga tushirish
CMD ["/app/bin/server"]