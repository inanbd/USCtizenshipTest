using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CivicsPrep.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddGovernorsAndV2025 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Governors",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    StateCode = table.Column<string>(type: "nvarchar(2)", maxLength: 2, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Since = table.Column<DateOnly>(type: "date", nullable: true),
                    AsOf = table.Column<DateOnly>(type: "date", nullable: false),
                    Source = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Governors", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Governors_StateCode",
                table: "Governors",
                column: "StateCode",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Governors");
        }
    }
}
